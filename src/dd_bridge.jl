abstract type DDBridgeAction end
struct DDBridgeWithdrawNow <: DDBridgeAction end
struct DDBridgeStay <: DDBridgeAction end

struct FiniteAgentDDBridgeModel
    agent_count::Int
    deposit::Float64
    withdrawal_premium::Float64
    productivity::Float64
    withdrawal_probability::Float64

    function FiniteAgentDDBridgeModel(
        agent_count::Integer,
        deposit::Real,
        withdrawal_premium::Real,
        productivity::Real,
        withdrawal_probability::Real,
    )
        count = Int(agent_count)
        principal = Float64(deposit)
        premium = Float64(withdrawal_premium)
        prod = Float64(productivity)
        probability = Float64(withdrawal_probability)
        count > 1 || throw(ArgumentError("agent_count must exceed one"))
        principal > 0.0 || throw(ArgumentError("deposit must be positive"))
        premium >= 0.0 ||
            throw(ArgumentError("withdrawal_premium must be nonnegative"))
        prod >= 0.0 || throw(ArgumentError("productivity must be nonnegative"))
        0.0 < probability <= 1.0 ||
            throw(ArgumentError("withdrawal_probability must be in (0, 1]"))
        new(count, principal, premium, prod, probability)
    end
end

struct DDBridgeState
    withdrawn_count::Int
    banking_count::Int
    vault::Float64

    function DDBridgeState(
        withdrawn_count::Integer,
        banking_count::Integer,
        vault::Real,
    )
        withdrawn = Int(withdrawn_count)
        banking = Int(banking_count)
        withdrawn >= 0 || throw(ArgumentError("withdrawn_count must be nonnegative"))
        banking > 0 || throw(ArgumentError("banking_count must be positive"))
        Float64(vault) >= 0.0 || throw(ArgumentError("vault must be nonnegative"))
        new(withdrawn, banking, Float64(vault))
    end
end

initial_bridge_state(model::FiniteAgentDDBridgeModel) =
    DDBridgeState(0, model.agent_count, model.agent_count * model.deposit)

early_claim(model::FiniteAgentDDBridgeModel) =
    (1.0 + model.withdrawal_premium) * model.deposit

function bridge_withdrawal_payment(
    model::FiniteAgentDDBridgeModel,
    vault::Float64,
)
    return min(early_claim(model), max(0.0, vault))
end

function simulate_recovery(
    model::FiniteAgentDDBridgeModel,
    state::DDBridgeState,
    future_other_withdrawals::Integer,
    ::DDBridgeWithdrawNow,
)
    return bridge_withdrawal_payment(model, state.vault)
end

function simulate_recovery(
    model::FiniteAgentDDBridgeModel,
    state::DDBridgeState,
    future_other_withdrawals::Integer,
    ::DDBridgeStay,
)
    future = clamp(Int(future_other_withdrawals), 0, state.banking_count - 1)
    remaining_vault = max(0.0, state.vault - future * early_claim(model))
    remaining_banks = state.banking_count - future
    return (
        (1.0 + model.withdrawal_premium + model.productivity) *
        remaining_vault / remaining_banks
    )
end

"""
    paired_recovery_payments(rng, model, state, trials)

Draw the number of future withdrawals by the other currently banking agents
once per trial and apply that same draw to the focal agent's withdraw-now and
stay counterfactuals.
"""
function paired_recovery_payments(
    rng::AbstractRNG,
    model::FiniteAgentDDBridgeModel,
    state::DDBridgeState,
    trials::Integer,
)
    trial_count = Int(trials)
    trial_count > 0 || throw(ArgumentError("trials must be positive"))
    other_agents = state.banking_count - 1
    distribution = Binomial(other_agents, model.withdrawal_probability)
    future_counts = rand(rng, distribution, trial_count)
    withdraw_payments = Float64[]
    stay_payments = Float64[]
    for future in future_counts
        push!(
            withdraw_payments,
            simulate_recovery(model, state, future, DDBridgeWithdrawNow()),
        )
        push!(
            stay_payments,
            simulate_recovery(model, state, future, DDBridgeStay()),
        )
    end
    return (; future_counts, withdraw_payments, stay_payments)
end
