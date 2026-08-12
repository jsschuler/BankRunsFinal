using BankRunsFinal
using CSV
using DataFrames
using Random

function main()
run_seed = RunSeed(isempty(ARGS) ? 20260723 : parse(UInt64, ARGS[1]))
destination = length(ARGS) >= 2 ?
    abspath(ARGS[2]) :
    joinpath(dirname(@__DIR__), "output", "dd_bridge_bounds.csv")

agent_count = 50
deposit = 1_000.0
trials = 10_000

rows = NamedTuple[]
scenario_index = 0
for premium in 0.50:0.05:0.60,
    productivity in 0.50:0.05:0.60,
    probability in 0.05:0.05:1.0
    scenario_index += 1
    model = FiniteAgentDDBridgeModel(
        agent_count,
        deposit,
        premium,
        productivity,
        probability,
    )
    decision_model = BridgeThreshold(
        (1.0 + premium) / (1.0 + premium + productivity),
    )
    state = initial_bridge_state(model)
    trial_seed = derive_seed(run_seed, 3, scenario_index)
    payments = paired_recovery_payments(
        Xoshiro(trial_seed),
        model,
        state,
        trials,
    )
    counts = paired_recovery_counts(
        payments.withdraw_payments,
        payments.stay_payments,
        fill(deposit, trials),
    )
    for decision in evaluate_bounds(decision_model, counts)
        push!(
            rows,
            (
                scenario_index,
                run_seed=run_seed.value,
                trial_seed,
                agent_count,
                deposit,
                withdrawal_premium=premium,
                productivity,
                withdrawal_probability=probability,
                bridge_threshold=decision_model.threshold,
                trials,
                bound=BankRunsFinal.bound_name(decision.bound),
                withdraw_full=counts.withdraw.full,
                withdraw_partial=counts.withdraw.partial,
                withdraw_zero=counts.withdraw.zero,
                stay_full=counts.stay.full,
                stay_partial=counts.stay.partial,
                stay_zero=counts.stay.zero,
                p_full_if_withdraw=
                    decision.probabilities.p_full_if_withdraw,
                p_full_if_stay=decision.probabilities.p_full_if_stay,
                withdraw=decision.withdraw,
            ),
        )
    end
end

frame = DataFrame(rows)
sort!(frame, [:scenario_index, :bound])
mkpath(dirname(destination))
CSV.write(destination, frame)
println("Wrote $(nrow(frame)) DD bridge bound results to $destination")
end

main()
