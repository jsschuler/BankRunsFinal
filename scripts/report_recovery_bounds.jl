using BankRunsFinal
using CSV
using DataFrames

length(ARGS) >= 1 || error(
    "usage: julia --project=. scripts/report_recovery_bounds.jl TRIALS.csv [OUTPUT.csv]",
)

input_path = abspath(ARGS[1])
output_path =
    length(ARGS) >= 2 ? abspath(ARGS[2]) : splitext(input_path)[1] * "_bounds.csv"

trials = CSV.read(input_path, DataFrame)
payment_columns = [:withdraw_payment, :stay_payment, :full_claim]
missing_columns = setdiff(payment_columns, propertynames(trials))
isempty(missing_columns) ||
    error("input is missing required columns: $(join(missing_columns, ", "))")

excluded_columns = Set([
    :withdraw_payment,
    :stay_payment,
    :full_claim,
    :trial_index,
    :trial_seed,
])
group_columns = [
    column for column in propertynames(trials) if !(column in excluded_columns)
]
isempty(group_columns) &&
    error("input must contain at least one scenario-identifying column")

rows = NamedTuple[]
for group in groupby(trials, group_columns)
    counts = paired_recovery_counts(
        group.withdraw_payment,
        group.stay_payment,
        group.full_claim,
    )
    decisions = evaluate_bounds(RelativeSafety(), counts)
    identifiers = NamedTuple(
        column => group[1, column] for column in group_columns
    )
    for decision in decisions
        push!(
            rows,
            merge(
                identifiers,
                (
                    bound=BankRunsFinal.bound_name(decision.bound),
                    trials=nrow(group),
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
            ),
        )
    end
end

result = DataFrame(rows)
sort!(result, vcat(group_columns, [:bound]))
mkpath(dirname(output_path))
CSV.write(output_path, result)
println("Wrote $(nrow(result)) bound results to $output_path")
