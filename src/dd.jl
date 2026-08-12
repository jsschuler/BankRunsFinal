using Distributions
using Random
using Statistics

Base.@kwdef struct DDConfig
    agent_count::Int = 50
    decision_draws::Int = 100
    search_realizations::Int = 100
    evaluation_realizations::Int = 1_000
    total_resources::Int = 1_000
    allocation_step::Int = 10
end

struct DDJob
    job_index::Int
    run_seed::RunSeed
    withdrawal_premium::Float64
    productivity::Float64
    withdrawal_probability::Float64
    rho::Float64
    utility_shift::Float64
    config::DDConfig
end

struct DDResult
    job_index::Int
    run_seed::UInt64
    model_seed::UInt64
    withdrawal_premium::Float64
    withdrawal_payout_rate::Float64
    productivity::Float64
    withdrawal_probability::Float64
    rho::Float64
    utility_shift::Float64
    optimal_deposit::Int
    optimal_outside_endowment::Int
    bank_formed::Bool
    search_expected_utility::Float64
    search_realizations::Int
    failure_count::Int
    evaluation_realizations::Int
    failure_rate::Float64
end

struct DDFixedResult
    job_index::Int
    run_seed::UInt64
    model_seed::UInt64
    withdrawal_premium::Float64
    withdrawal_payout_rate::Float64
    productivity::Float64
    withdrawal_probability::Float64
    rho::Float64
    utility_shift::Float64
    deposit::Int
    outside_endowment::Int
    evaluation_realizations::Int
    failure_count::Int
    failure_rate::Float64
    mean_initial_withdrawals::Float64
    mean_executed_initial_withdrawals::Float64
    mean_endogenous_withdrawals::Float64
    mean_post_failure_withdrawals::Float64
    mean_total_withdrawals::Float64
    mean_shortfall_count::Float64
    mean_shortfall_amount::Float64
    mean_realized_utility::Float64
end

mutable struct DDState
    withdrawn_count::Int
    banking_count::Int
    outside_endowment::Int
    deposit::Int
    vault::Float64
end

function validate(config::DDConfig)
    config.agent_count > 0 || throw(ArgumentError("agent_count must be positive"))
    config.decision_draws > 0 ||
        throw(ArgumentError("decision_draws must be positive"))
    config.search_realizations > 0 ||
        throw(ArgumentError("search_realizations must be positive"))
    config.evaluation_realizations > 0 ||
        throw(ArgumentError("evaluation_realizations must be positive"))
    config.total_resources >= 0 ||
        throw(ArgumentError("total_resources must be nonnegative"))
    config.allocation_step > 0 ||
        throw(ArgumentError("allocation_step must be positive"))
    config.total_resources % config.allocation_step == 0 ||
        throw(ArgumentError("allocation_step must divide total_resources"))
    return config
end

function DDJob(
    job_index::Integer,
    run_seed::RunSeed,
    withdrawal_premium::Real,
    productivity::Real,
    withdrawal_probability::Real,
    rho::Real,
    config::DDConfig=DDConfig(),
    utility_shift::Real=1.0,
)
    epsilon = Float64(withdrawal_premium)
    prod = Float64(productivity)
    probability = Float64(withdrawal_probability)
    risk_aversion = Float64(rho)
    shift = Float64(utility_shift)
    epsilon >= 0.0 || throw(ArgumentError("withdrawal_premium must be nonnegative"))
    prod >= 0.0 || throw(ArgumentError("productivity must be nonnegative"))
    0.0 <= probability <= 1.0 ||
        throw(ArgumentError("withdrawal_probability must be in [0, 1]"))
    risk_aversion >= 0.0 || throw(ArgumentError("rho must be nonnegative"))
    shift > 0.0 || throw(ArgumentError("utility_shift must be positive"))
    validate(config)
    return DDJob(
        Int(job_index),
        run_seed,
        epsilon,
        prod,
        probability,
        risk_aversion,
        shift,
        config,
    )
end

"""
    dd_jobs(run_seed; ...)

Construct the common DD parameter grid for log-utility (`rho = 1`) and
risk-neutral (`rho = 0`) agents. Job indices are stable and are the coordinates
used to order output records. `withdrawal_probability` parameterizes the
agent's prior over total eventual withdrawals.
"""
function dd_jobs(
    run_seed::RunSeed;
    withdrawal_premia=0.50:0.05:0.60,
    productivities=0.50:0.05:0.60,
    withdrawal_probabilities=0.05:0.05:1.0,
    rhos=(1.0, 0.0),
    utility_shifts=(1.0,),
    config::DDConfig=DDConfig(),
)
    jobs = DDJob[]
    job_index = 0
    for rho in rhos,
        shift in utility_shifts,
        premium in withdrawal_premia,
        productivity in productivities,
        probability in withdrawal_probabilities
        job_index += 1
        push!(
            jobs,
            DDJob(
                job_index,
                run_seed,
                premium,
                productivity,
                probability,
                rho,
                config,
                shift,
            ),
        )
    end
    return jobs
end

"""
    sample_conditioned_binomial(rng, agent_count, probability, observed, draws)

Draw total withdrawal counts from `Binomial(agent_count, probability)`
conditional on the count being at least `observed`.

The distribution is the agent's prior over total eventual withdrawals. The
observed count includes all withdrawals seen so far and includes the focal
agent when it evaluates withdrawing now.

This is the corrected counterpart to the legacy DD sampler. The legacy code
conditions on `X > observed` and then applies a shifted inverse-CDF lookup.
The replication implementation conditions directly on `X ≥ observed`.
"""
function sample_conditioned_binomial(
    rng::AbstractRNG,
    agent_count::Integer,
    probability::Real,
    observed::Integer,
    draws::Integer,
)
    n = Int(agent_count)
    lower = Int(observed)
    sample_count = Int(draws)
    p = Float64(probability)

    n >= 0 || throw(ArgumentError("agent_count must be nonnegative"))
    0.0 <= p <= 1.0 || throw(ArgumentError("probability must be in [0, 1]"))
    0 <= lower <= n ||
        throw(ArgumentError("observed must be between zero and agent_count"))
    sample_count >= 0 || throw(ArgumentError("draws must be nonnegative"))

    distribution = Binomial(n, p)
    support = lower:n
    log_weights = [logpdf(distribution, count) for count in support]
    maximum_log_weight = maximum(log_weights)
    isfinite(maximum_log_weight) ||
        throw(ArgumentError("conditioning event X ≥ observed has zero probability"))

    # Normalize the finite conditional support in log space. This avoids the
    # cancellation in `1 - cdf(distribution, lower - 1)` when the upper tail is
    # positive but smaller than floating-point precision near one.
    cumulative_weights = cumsum(exp.(log_weights .- maximum_log_weight))
    total_weight = cumulative_weights[end]

    samples = Vector{Int}(undef, sample_count)
    for index in eachindex(samples)
        target = rand(rng) * total_weight
        support_index = searchsortedfirst(cumulative_weights, target)
        samples[index] = support[min(support_index, length(support))]
    end
    return samples
end

function shifted_crra(
    consumption::Real,
    rho::Float64,
    utility_shift::Float64=1.0,
)
    value = max(0.0, Float64(consumption))
    utility_shift > 0.0 ||
        throw(ArgumentError("utility_shift must be positive"))
    if rho == 1.0
        return log(utility_shift + value)
    end
    return (utility_shift + value)^(1.0 - rho) / (1.0 - rho)
end

function clone(state::DDState)
    return DDState(
        state.withdrawn_count,
        state.banking_count,
        state.outside_endowment,
        state.deposit,
        state.vault,
    )
end

function withdraw!(state::DDState, job::DDJob)
    if state.banking_count == 0
        return 0.0
    end
    state.banking_count -= 1
    state.withdrawn_count += 1
    promised = (1.0 + job.withdrawal_premium) * state.deposit
    payment = min(promised, state.vault)
    state.vault = max(0.0, state.vault - payment)
    return payment
end

function final_payment(state::DDState, job::DDJob)
    state.banking_count == 0 && return 0.0
    return (
        (1.0 + job.withdrawal_premium + job.productivity) *
        state.vault / state.banking_count
    )
end

function expected_action_utility(
    rng::AbstractRNG,
    state::DDState,
    job::DDJob,
    withdraw_now::Bool,
)
    known_withdrawals = state.withdrawn_count + Int(withdraw_now)
    remaining_after_decision = state.banking_count - Int(withdraw_now)
    total_counts = sample_conditioned_binomial(
        rng,
        job.config.agent_count,
        job.withdrawal_probability,
        known_withdrawals,
        job.config.decision_draws,
    )

    utility_sum = 0.0
    outcome_count = 0
    if withdraw_now
        # The focal agent is uniformly uncertain about its position among the
        # withdrawals that have not yet been observed. Preserve the legacy
        # averaging convention by recording every possible queue-position payoff.
        for total_count in total_counts
            withdrawals_including_focal =
                total_count - known_withdrawals + 1
            simulated = clone(state)
            for _ in 1:withdrawals_including_focal
                payment = withdraw!(simulated, job)
                utility_sum += shifted_crra(
                    state.outside_endowment + payment,
                    job.rho,
                    job.utility_shift,
                )
                outcome_count += 1
            end
        end
    else
        for total_count in total_counts
            future_withdrawals = min(
                total_count - known_withdrawals,
                remaining_after_decision,
            )
            simulated = clone(state)
            for _ in 1:future_withdrawals
                withdraw!(simulated, job)
            end
            utility_sum += shifted_crra(
                state.outside_endowment + final_payment(simulated, job),
                job.rho,
                job.utility_shift,
            )
            outcome_count += 1
        end
    end

    return utility_sum / outcome_count
end

function realize_model(
    rng::AbstractRNG,
    job::DDJob,
    deposit::Int,
)
    if deposit == 0
        consumption = Float64(job.config.total_resources)
        return (;
            failed=false,
            mean_utility=shifted_crra(
                consumption,
                job.rho,
                job.utility_shift,
            ),
            initial_withdrawal_count=0,
            executed_initial_withdrawal_count=0,
            endogenous_withdrawal_count=0,
            post_failure_withdrawal_count=0,
            total_withdrawal_count=0,
            shortfall_count=0,
            shortfall_amount=0.0,
        )
    end

    state = DDState(
        0,
        job.config.agent_count,
        job.config.total_resources - deposit,
        deposit,
        Float64(job.config.agent_count * deposit),
    )

    initial_withdrawal_count = rand(
        rng,
        Binomial(job.config.agent_count, job.withdrawal_probability),
    )
    activation_order = vcat(
        fill(true, initial_withdrawal_count),
        fill(false, job.config.agent_count - initial_withdrawal_count),
    )
    shuffle!(rng, activation_order)

    consumptions = Float64[]
    failed = false
    executed_initial_withdrawal_count = 0
    endogenous_withdrawal_count = 0
    post_failure_withdrawal_count = 0
    shortfall_count = 0
    shortfall_amount = 0.0
    for initial_withdrawer in activation_order
        if initial_withdrawer
            promised = (1.0 + job.withdrawal_premium) * state.deposit
            payment = withdraw!(state, job)
            push!(
                consumptions,
                state.outside_endowment + payment,
            )
            executed_initial_withdrawal_count += 1
            shortfall = max(0.0, promised - payment)
            if shortfall > 8eps(promised)
                shortfall_count += 1
                shortfall_amount += shortfall
                failed = true
            end
        else
            withdraw_utility = expected_action_utility(rng, state, job, true)
            stay_utility = expected_action_utility(rng, state, job, false)
            if withdraw_utility > stay_utility
                promised = (1.0 + job.withdrawal_premium) * state.deposit
                payment = withdraw!(state, job)
                push!(
                    consumptions,
                    state.outside_endowment + payment,
                )
                endogenous_withdrawal_count += 1
                shortfall = max(0.0, promised - payment)
                if shortfall > 8eps(promised)
                    shortfall_count += 1
                    shortfall_amount += shortfall
                    failed = true
                end
            end
        end

        if failed
            break
        end
    end

    if failed
        while state.banking_count > 0
            promised = (1.0 + job.withdrawal_premium) * state.deposit
            payment = withdraw!(state, job)
            push!(
                consumptions,
                state.outside_endowment + payment,
            )
            post_failure_withdrawal_count += 1
            shortfall = max(0.0, promised - payment)
            if shortfall > 8eps(promised)
                shortfall_count += 1
                shortfall_amount += shortfall
            end
        end
    else
        payout = final_payment(state, job)
        append!(
            consumptions,
            fill(state.outside_endowment + payout, state.banking_count),
        )
    end

    mean_utility = mean(
        value -> shifted_crra(value, job.rho, job.utility_shift),
        consumptions,
    )
    total_withdrawal_count =
        executed_initial_withdrawal_count +
        endogenous_withdrawal_count +
        post_failure_withdrawal_count
    return (;
        failed,
        mean_utility,
        initial_withdrawal_count,
        executed_initial_withdrawal_count,
        endogenous_withdrawal_count,
        post_failure_withdrawal_count,
        total_withdrawal_count,
        shortfall_count,
        shortfall_amount,
    )
end

"""
    run_dd_job(job)

Perform the approximate-rational-expectations allocation search, then estimate
failure at the selected allocation using a separate holdout sample. Candidate
allocations and premium comparisons use common random-number seeds.
"""
function run_dd_job(job::DDJob)
    # This comparison seed deliberately excludes the withdrawal premium so
    # matched premium jobs use common random numbers.
    model_seed = derive_seed(
        job.run_seed,
        1,
        reinterpret(UInt64, job.productivity),
        reinterpret(UInt64, job.withdrawal_probability),
        reinterpret(UInt64, job.rho),
    )

    best_deposit = 0
    best_utility = -Inf

    for deposit in 0:job.config.allocation_step:job.config.total_resources
        utility_sum = 0.0
        for realization_index in 1:job.config.search_realizations
            realization_seed = derive_seed(
                RunSeed(model_seed),
                1,
                deposit,
                realization_index,
            )
            rng = Xoshiro(realization_seed)
            realization = realize_model(rng, job, deposit)
            utility_sum += realization.mean_utility
        end
        expected_utility = utility_sum / job.config.search_realizations
        if expected_utility > best_utility
            best_deposit = deposit
            best_utility = expected_utility
        end
    end

    # Independent holdout stream: allocation selection never sees these draws.
    failure_count = 0
    for realization_index in 1:job.config.evaluation_realizations
        realization_seed = derive_seed(
            RunSeed(model_seed),
            2,
            realization_index,
        )
        rng = Xoshiro(realization_seed)
        realization = realize_model(rng, job, best_deposit)
        failure_count += realization.failed
    end

    return DDResult(
        job.job_index,
        job.run_seed.value,
        model_seed,
        job.withdrawal_premium,
        1.0 + job.withdrawal_premium,
        job.productivity,
        job.withdrawal_probability,
        job.rho,
        job.utility_shift,
        best_deposit,
        job.config.total_resources - best_deposit,
        best_deposit > 0,
        best_utility,
        job.config.search_realizations,
        failure_count,
        job.config.evaluation_realizations,
        failure_count / job.config.evaluation_realizations,
    )
end

"""
    run_dd_fixed_job(job, deposit=job.config.total_resources)

Evaluate a prespecified common deposit allocation without optimizing over the
allocation grid. Failure means that at least one early claimant receives less
than the promised early-withdrawal payment; exact exhaustion after honoring a
claim in full is not failure. Matched premium jobs use common random numbers.
"""
function run_dd_fixed_job(
    job::DDJob,
    deposit::Integer=job.config.total_resources,
)
    fixed_deposit = Int(deposit)
    0 <= fixed_deposit <= job.config.total_resources ||
        throw(ArgumentError("deposit must lie between zero and total_resources"))

    model_seed = derive_seed(
        job.run_seed,
        1,
        reinterpret(UInt64, job.productivity),
        reinterpret(UInt64, job.withdrawal_probability),
        reinterpret(UInt64, job.rho),
    )

    failure_count = 0
    initial_sum = 0
    executed_initial_sum = 0
    endogenous_sum = 0
    post_failure_sum = 0
    total_sum = 0
    shortfall_count_sum = 0
    shortfall_amount_sum = 0.0
    utility_sum = 0.0

    for realization_index in 1:job.config.evaluation_realizations
        realization_seed = derive_seed(
            RunSeed(model_seed),
            3,
            realization_index,
        )
        realization = realize_model(
            Xoshiro(realization_seed),
            job,
            fixed_deposit,
        )
        failure_count += realization.failed
        initial_sum += realization.initial_withdrawal_count
        executed_initial_sum += realization.executed_initial_withdrawal_count
        endogenous_sum += realization.endogenous_withdrawal_count
        post_failure_sum += realization.post_failure_withdrawal_count
        total_sum += realization.total_withdrawal_count
        shortfall_count_sum += realization.shortfall_count
        shortfall_amount_sum += realization.shortfall_amount
        utility_sum += realization.mean_utility
    end

    count = job.config.evaluation_realizations
    return DDFixedResult(
        job.job_index,
        job.run_seed.value,
        model_seed,
        job.withdrawal_premium,
        1.0 + job.withdrawal_premium,
        job.productivity,
        job.withdrawal_probability,
        job.rho,
        job.utility_shift,
        fixed_deposit,
        job.config.total_resources - fixed_deposit,
        count,
        failure_count,
        failure_count / count,
        initial_sum / count,
        executed_initial_sum / count,
        endogenous_sum / count,
        post_failure_sum / count,
        total_sum / count,
        shortfall_count_sum / count,
        shortfall_amount_sum / count,
        utility_sum / count,
    )
end
