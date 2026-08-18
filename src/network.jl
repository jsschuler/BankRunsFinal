abstract type DepositInsuranceModel end
struct NoDepositInsurance <: DepositInsuranceModel end

struct FixedDepositInsurance <: DepositInsuranceModel
    maximum_payment::Float64

    function FixedDepositInsurance(maximum_payment::Real)
        value = Float64(maximum_payment)
        value >= 0.0 ||
            throw(ArgumentError("maximum insurance payment must be nonnegative"))
        new(value)
    end
end

struct AdaptiveDepositInsurance <: DepositInsuranceModel end

abstract type NetworkAction end
struct WithdrawNow <: NetworkAction end
struct StayUntilAfterExpectedWithdrawals <: NetworkAction end

mutable struct NetworkState{I<:DepositInsuranceModel}
    deposits::Vector{Float64}
    banked::BitVector
    active_agents::Vector{Int}
    active_position::Vector{Int}
    vault::Float64
    withdrawal_order::Vector{Int}
    insurance::I

    function NetworkState{I}(
        deposits::Vector{Float64},
        banked::BitVector,
        active_agents::Vector{Int},
        active_position::Vector{Int},
        vault::Float64,
        withdrawal_order::Vector{Int},
        insurance::I,
    ) where {I<:DepositInsuranceModel}
        new{I}(
            deposits,
            banked,
            active_agents,
            active_position,
            vault,
            withdrawal_order,
            insurance,
        )
    end

    function NetworkState(
        deposits::AbstractVector{<:Real},
        reserve_ratio::Real,
        insurance::I=NoDepositInsurance(),
    ) where {I<:DepositInsuranceModel}
        values = Float64.(deposits)
        isempty(values) && throw(ArgumentError("at least one agent is required"))
        all(values .> 0.0) ||
            throw(ArgumentError("deposits must be strictly positive"))
        ratio = Float64(reserve_ratio)
        ratio >= 0.0 || throw(ArgumentError("reserve_ratio must be nonnegative"))
        new{I}(
            values,
            trues(length(values)),
            collect(eachindex(values)),
            collect(eachindex(values)),
            ratio * sum(values),
            Int[],
            insurance,
        )
    end
end

struct SubjectiveSnapshot{I<:DepositInsuranceModel}
    deposits::Vector{Float64}
    banked::BitVector
    active_agents::Vector{Int}
    active_position::Vector{Int}
    vault::Float64
    withdrawal_order::Vector{Int}
    insurance::I
end

function subjective_snapshot(state::NetworkState)
    return SubjectiveSnapshot(
        copy(state.deposits),
        copy(state.banked),
        copy(state.active_agents),
        copy(state.active_position),
        state.vault,
        copy(state.withdrawal_order),
        state.insurance,
    )
end

function clone(snapshot::SubjectiveSnapshot)
    return NetworkState{typeof(snapshot.insurance)}(
        copy(snapshot.deposits),
        copy(snapshot.banked),
        copy(snapshot.active_agents),
        copy(snapshot.active_position),
        snapshot.vault,
        copy(snapshot.withdrawal_order),
        snapshot.insurance,
    )
end

insurance_floor(
    ::NoDepositInsurance,
    state::NetworkState,
    deposit::Float64,
    additional_history::AbstractVector{<:Integer}=Int[],
) = 0.0

insurance_floor(
    model::FixedDepositInsurance,
    state::NetworkState,
    deposit::Float64,
    additional_history::AbstractVector{<:Integer}=Int[],
) = min(deposit, model.maximum_payment)

function insurance_floor(
    ::AdaptiveDepositInsurance,
    state::NetworkState,
    deposit::Float64,
    additional_history::AbstractVector{<:Integer}=Int[],
)
    maximum_observed = 0.0
    for index in state.withdrawal_order
        maximum_observed = max(maximum_observed, state.deposits[index])
    end
    for index in additional_history
        maximum_observed = max(maximum_observed, state.deposits[Int(index)])
    end
    return min(deposit, maximum_observed)
end

function withdraw!(state::NetworkState, agent_index::Integer)
    index = Int(agent_index)
    checkbounds(state.deposits, index)
    state.banked[index] ||
        throw(ArgumentError("agent $index has already withdrawn"))

    deposit = state.deposits[index]
    available = max(0.0, state.vault)
    payment = min(
        deposit,
        available >= deposit ?
        deposit :
        max(available, insurance_floor(state.insurance, state, deposit)),
    )
    state.vault = max(0.0, state.vault - deposit)
    state.banked[index] = false
    position = state.active_position[index]
    final_agent = state.active_agents[end]
    state.active_agents[position] = final_agent
    state.active_position[final_agent] = position
    pop!(state.active_agents)
    state.active_position[index] = 0
    push!(state.withdrawal_order, index)
    return payment
end

function simulate_recovery(
    snapshot::SubjectiveSnapshot,
    focal_agent::Integer,
    additional_withdrawal_order::AbstractVector{<:Integer},
    ::WithdrawNow,
)
    simulated = clone(snapshot)
    return withdraw!(simulated, focal_agent)
end

function simulate_recovery(
    snapshot::SubjectiveSnapshot,
    focal_agent::Integer,
    additional_withdrawal_order::AbstractVector{<:Integer},
    ::StayUntilAfterExpectedWithdrawals,
)
    simulated = clone(snapshot)
    focal = Int(focal_agent)
    for agent_index in additional_withdrawal_order
        index = Int(agent_index)
        index == focal && continue
        simulated.banked[index] && withdraw!(simulated, index)
    end
    return withdraw!(simulated, focal)
end

function paired_recovery_payments(
    snapshot::SubjectiveSnapshot,
    focal_agent::Integer,
    additional_withdrawal_orders::AbstractVector{<:AbstractVector{<:Integer}},
)
    withdraw_payments = Float64[]
    stay_payments = Float64[]
    for order in additional_withdrawal_orders
        push!(
            withdraw_payments,
            simulate_recovery(snapshot, focal_agent, order, WithdrawNow()),
        )
        push!(
            stay_payments,
            simulate_recovery(
                snapshot,
                focal_agent,
                order,
                StayUntilAfterExpectedWithdrawals(),
            ),
        )
    end
    return (; withdraw_payments, stay_payments)
end

abstract type BeliefModel end

"""
Production default. A point estimate of the local withdrawal
probability---the observed neighbor withdrawal fraction, floored at the
baseline rate---is plugged directly into a Binomial for the count of
future withdrawals. Carries no representation of estimation uncertainty.
"""
struct PointEstimateBelief <: BeliefModel end

"""
Alternative belief law for the robustness check described in the paper's
belief-model qualification. Reproduces the paper's own analytical belief
law (eqs. \\ref{eq:tau}--\\ref{eq:belief} in `paper_revision/paper.Rnw`)
inside the simulation, instead of the ad hoc point estimate above. The
agent treats total population-wide withdrawals as drawn from a
`Geometric(p0)`, truncated from below at the locally implied count
`round(K * local_rate)`, where `p0` is the scenario's baseline withdrawal
probability (reused for both the exogenous shock process and this belief,
exactly as the paper argues for internal consistency) and `K` is the
total agent count. `p0` and `local_rate` are fixed, not-updated
parameters here, exactly as in the paper's text: this is support
truncation given what the agent locally observes, not Bayesian updating.
"""
struct TruncatedGeometricBelief <: BeliefModel end

struct NetworkScenario{G<:AbstractGraph,I<:DepositInsuranceModel,B<:BeliefModel}
    graph::G
    deposits::Vector{Float64}
    reserve_ratio::Float64
    insurance::I
    initial_withdrawals::Vector{Int}
    baseline_withdrawal_probability::Float64
    decision_draws::Int
    belief::B

    function NetworkScenario(
        graph::G,
        deposits::AbstractVector{<:Real},
        reserve_ratio::Real,
        insurance::I,
        initial_withdrawals::AbstractVector{<:Integer},
        baseline_withdrawal_probability::Real,
        decision_draws::Integer,
        belief::B=PointEstimateBelief(),
    ) where {G<:AbstractGraph,I<:DepositInsuranceModel,B<:BeliefModel}
        values = Float64.(deposits)
        nv(graph) == length(values) ||
            throw(ArgumentError("graph and deposit counts must match"))
        initial = unique(Int.(initial_withdrawals))
        all(index -> 1 <= index <= length(values), initial) ||
            throw(ArgumentError("initial withdrawal index out of bounds"))
        probability = Float64(baseline_withdrawal_probability)
        0.0 < probability <= 1.0 ||
            throw(ArgumentError("baseline probability must be in (0, 1]"))
        draws = Int(decision_draws)
        draws > 0 || throw(ArgumentError("decision_draws must be positive"))
        new{G,I,B}(
            graph,
            values,
            Float64(reserve_ratio),
            insurance,
            initial,
            probability,
            draws,
            belief,
        )
    end
end

abstract type AbstractNetworkModel end

abstract type NetworkExecutionModel <: AbstractNetworkModel end

"""
Fully materialized execution model for small networks and object-level
debugging. Every subjective counterfactual uses an independent cloned state.
"""
struct SmallObjectNetworkModel{M<:AbstractNetworkModel} <: NetworkExecutionModel
    economic_model::M
end

"""
Sparse execution model for large networks. Subjective trials share objective
deposit data and carry only the current vault plus sparse withdrawal indices.
"""
struct LargeSparseNetworkModel{M<:AbstractNetworkModel} <: NetworkExecutionModel
    economic_model::M
end

struct ComparativeNetworkModel{S<:NetworkScenario} <: AbstractNetworkModel
    scenario::S
end

struct ThresholdNetworkModel{S<:NetworkScenario} <: AbstractNetworkModel
    scenario::S
    threshold::Float64

    function ThresholdNetworkModel(scenario::S, threshold::Real) where {S<:NetworkScenario}
        rule = BridgeThreshold(threshold)
        new{S}(scenario, rule.threshold)
    end
end

struct ExplicitUtilityNetworkModel{S<:NetworkScenario} <: AbstractNetworkModel
    scenario::S
    rho::Float64
    gross_return::Float64

    function ExplicitUtilityNetworkModel(
        scenario::S,
        rho::Real,
        gross_return::Real,
    ) where {S<:NetworkScenario}
        rule = ExplicitUtility(rho, gross_return)
        new{S}(scenario, rule.rho, rule.gross_return)
    end
end

struct NetworkRunResult
    model_name::String
    run_seed::UInt64
    failed::Bool
    initial_withdrawals::Int
    endogenous_withdrawals::Int
    total_withdrawals::Int
    final_vault::Float64
    rounds::Int
end

scenario(model::AbstractNetworkModel) = model.scenario
scenario(model::NetworkExecutionModel) = scenario(model.economic_model)
model_name(::ComparativeNetworkModel) = "comparative"
model_name(::ThresholdNetworkModel) = "threshold"
model_name(::ExplicitUtilityNetworkModel) = "explicit_utility"
model_name(model::NetworkExecutionModel) = model_name(model.economic_model)

function local_withdrawal_probability(
    model::AbstractNetworkModel,
    state::NetworkState,
    focal_agent::Integer,
)
    neighbors = all_neighbors(scenario(model).graph, Int(focal_agent))
    isempty(neighbors) &&
        return scenario(model).baseline_withdrawal_probability
    withdrawn_neighbors = count(index -> !state.banked[index], neighbors)
    local_fraction = withdrawn_neighbors / length(neighbors)
    return max(scenario(model).baseline_withdrawal_probability, local_fraction)
end

function draw_future_withdrawal_count(
    rng::AbstractRNG,
    ::PointEstimateBelief,
    model::AbstractNetworkModel,
    state::NetworkState,
    focal_agent::Integer,
    eligible_count::Integer,
)
    probability = local_withdrawal_probability(model, state, focal_agent)
    return rand(rng, Binomial(Int(eligible_count), probability))
end

function draw_future_withdrawal_count(
    rng::AbstractRNG,
    ::TruncatedGeometricBelief,
    model::AbstractNetworkModel,
    state::NetworkState,
    focal_agent::Integer,
    eligible_count::Integer,
)
    population = length(scenario(model).deposits)
    already_withdrawn = population - length(state.active_agents)
    neighbors = all_neighbors(scenario(model).graph, Int(focal_agent))
    local_rate = isempty(neighbors) ? 0.0 :
        count(index -> !state.banked[index], neighbors) / length(neighbors)
    lower_bound = round(Int, population * local_rate)
    p0 = scenario(model).baseline_withdrawal_probability
    # By the Geometric's memorylessness, W | W >= lower_bound is
    # distributed exactly as lower_bound + Geometric(p0) -- this reproduces
    # eqs. \ref{eq:tau}--\ref{eq:belief} exactly, not an approximation.
    total_belief = lower_bound + rand(rng, Geometric(p0))
    return clamp(total_belief - already_withdrawn, 0, Int(eligible_count))
end

function sparse_sample_ranks(
    rng::AbstractRNG,
    population_size::Integer,
    sample_size::Integer,
)
    population = Int(population_size)
    count = Int(sample_size)
    0 <= count <= population ||
        throw(ArgumentError("sample size must be in [0, population_size]"))
    count == 0 && return Int[]

    if count <= population ÷ 2
        selected_set = BitSet()
        for upper in (population - count + 1):population
            candidate = rand(rng, 1:upper)
            push!(
                selected_set,
                candidate in selected_set ? upper : candidate,
            )
        end
        selected = collect(selected_set)
        shuffle!(rng, selected)
        return selected
    end

    excluded = BitSet(
        sparse_sample_ranks(rng, population, population - count),
    )
    selected = [
        rank for rank in 1:population if !(rank in excluded)
    ]
    shuffle!(rng, selected)
    return selected
end

function sparse_sample_active_agents(
    rng::AbstractRNG,
    state::NetworkState,
    focal_agent::Integer,
    sample_size::Integer,
)
    focal = Int(focal_agent)
    focal_position = state.active_position[focal]
    focal_position > 0 ||
        throw(ArgumentError("focal agent must still be banking"))
    eligible_count = length(state.active_agents) - 1
    ranks = sparse_sample_ranks(rng, eligible_count, sample_size)
    return [
        state.active_agents[
            rank < focal_position ? rank : rank + 1
        ]
        for rank in ranks
    ]
end

function subjective_withdrawal_orders(
    rng::AbstractRNG,
    model::AbstractNetworkModel,
    state::NetworkState,
    focal_agent::Integer,
)
    focal = Int(focal_agent)
    eligible_count = length(state.active_agents) - 1
    orders = Vector{Vector{Int}}(undef, scenario(model).decision_draws)
    for trial in eachindex(orders)
        future_count = draw_future_withdrawal_count(
            rng,
            scenario(model).belief,
            model,
            state,
            focal,
            eligible_count,
        )
        orders[trial] = sparse_sample_active_agents(
            rng,
            state,
            focal,
            future_count,
        )
    end
    return orders
end

function network_decision(
    model::ComparativeNetworkModel,
    payments,
    deposit::Float64,
)
    counts = paired_recovery_counts(
        payments.withdraw_payments,
        payments.stay_payments,
        fill(deposit, length(payments.withdraw_payments)),
    )
    probabilities = recovery_probabilities(counts, FullRecoveryOnly())
    return should_withdraw(probabilities, RelativeSafety())
end

network_decision(
    model::NetworkExecutionModel,
    payments,
    deposit::Float64,
) = network_decision(model.economic_model, payments, deposit)

function subjective_payments(
    model::SmallObjectNetworkModel,
    state::NetworkState,
    focal_agent::Integer,
    orders::AbstractVector{<:AbstractVector{<:Integer}},
)
    snapshot = subjective_snapshot(state)
    return paired_recovery_payments(snapshot, focal_agent, orders)
end

function sparse_withdrawal_payment(
    state::NetworkState,
    focal_agent::Integer,
    available_vault::Float64,
    additional_history::AbstractVector{<:Integer}=Int[],
)
    deposit = state.deposits[Int(focal_agent)]
    return min(
        deposit,
        available_vault >= deposit ?
        deposit :
        max(
            max(0.0, available_vault),
            insurance_floor(
                state.insurance,
                state,
                deposit,
                additional_history,
            ),
        ),
    )
end

function subjective_payments(
    model::LargeSparseNetworkModel,
    state::NetworkState,
    focal_agent::Integer,
    orders::AbstractVector{<:AbstractVector{<:Integer}},
)
    withdraw_payment =
        sparse_withdrawal_payment(state, focal_agent, state.vault)
    withdraw_payments = fill(withdraw_payment, length(orders))
    stay_payments = Vector{Float64}(undef, length(orders))
    for trial in eachindex(orders)
        withdrawn_principal = sum(
            index -> state.deposits[Int(index)],
            orders[trial];
            init=0.0,
        )
        available = max(0.0, state.vault - withdrawn_principal)
        stay_payments[trial] =
            sparse_withdrawal_payment(
                state,
                focal_agent,
                available,
                orders[trial],
            )
    end
    return (; withdraw_payments, stay_payments)
end

function subjective_payments(
    model::AbstractNetworkModel,
    state::NetworkState,
    focal_agent::Integer,
    orders::AbstractVector{<:AbstractVector{<:Integer}},
)
    return subjective_payments(
        SmallObjectNetworkModel(model),
        state,
        focal_agent,
        orders,
    )
end

function network_decision(
    model::ThresholdNetworkModel,
    payments,
    deposit::Float64,
)
    counts = paired_recovery_counts(
        payments.withdraw_payments,
        payments.stay_payments,
        fill(deposit, length(payments.withdraw_payments)),
    )
    probabilities = recovery_probabilities(counts, FullRecoveryOnly())
    return should_withdraw(probabilities, BridgeThreshold(model.threshold))
end

function network_decision(
    model::ExplicitUtilityNetworkModel,
    payments,
    deposit::Float64,
)
    return should_withdraw(
        payments.withdraw_payments,
        payments.stay_payments,
        ExplicitUtility(model.rho, model.gross_return),
    )
end

function run_network_model(model::AbstractNetworkModel, run_seed::RunSeed)
    config = scenario(model)
    state = NetworkState(config.deposits, config.reserve_ratio, config.insurance)
    for agent in config.initial_withdrawals
        withdraw!(state, agent)
    end

    rng = Xoshiro(derive_seed(run_seed, 4))
    rounds = 0
    changed = true
    while changed && state.vault > 0.0
        changed = false
        rounds += 1
        banking_agents = findall(state.banked)
        shuffle!(rng, banking_agents)
        for focal in banking_agents
            state.banked[focal] || continue
            orders = subjective_withdrawal_orders(rng, model, state, focal)
            payments = subjective_payments(model, state, focal, orders)
            if network_decision(model, payments, state.deposits[focal])
                withdraw!(state, focal)
                changed = true
            end
            state.vault > 0.0 || break
        end
    end

    total = length(state.withdrawal_order)
    initial = length(config.initial_withdrawals)
    return NetworkRunResult(
        model_name(model),
        run_seed.value,
        state.vault <= 0.0,
        initial,
        total - initial,
        total,
        state.vault,
        rounds,
    )
end
