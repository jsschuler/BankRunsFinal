using CSV
using DataFrames
using Statistics

function wilson_interval(successes::Integer, trials::Integer; z::Float64=1.959963984540054)
    p = successes / trials
    denominator = 1.0 + z^2 / trials
    center = (p + z^2 / (2trials)) / denominator
    half_width =
        z * sqrt(p * (1.0 - p) / trials + z^2 / (4trials^2)) / denominator
    return (max(0.0, center - half_width), min(1.0, center + half_width))
end

length(ARGS) >= 1 || error(
    "usage: julia --project=. scripts/report_dd_core.jl INPUT.csv [OUTPUT_PREFIX]",
)

input_path = abspath(ARGS[1])
output_prefix =
    length(ARGS) >= 2 ? abspath(ARGS[2]) : splitext(input_path)[1] * "_report"

frame = CSV.read(input_path, DataFrame)
required = [
    :rho,
    :productivity,
    :withdrawal_probability,
    :withdrawal_premium,
    :failure_count,
    :evaluation_realizations,
    :failure_rate,
]
missing_columns = setdiff(required, propertynames(frame))
isempty(missing_columns) ||
    error("input is missing required columns: $(join(missing_columns, ", "))")

sort!(
    frame,
    [:rho, :productivity, :withdrawal_probability, :withdrawal_premium],
)

lower = Float64[]
upper = Float64[]
for row in eachrow(frame)
    interval = wilson_interval(row.failure_count, row.evaluation_realizations)
    push!(lower, interval[1])
    push!(upper, interval[2])
end
frame.failure_ci95_lower = lower
frame.failure_ci95_upper = upper

comparison_rows = NamedTuple[]
group_columns = [:rho, :productivity, :withdrawal_probability]
for group in groupby(frame, group_columns)
    premiums = collect(group.withdrawal_premium)
    rates = collect(group.failure_rate)
    differences = diff(rates)
    minimum_change = isempty(differences) ? NaN : minimum(differences)
    maximum_change = isempty(differences) ? NaN : maximum(differences)
    push!(
        comparison_rows,
        (
            rho=group.rho[1],
            productivity=group.productivity[1],
            withdrawal_probability=group.withdrawal_probability[1],
            premium_count=length(premiums),
            minimum_failure_rate=minimum(rates),
            maximum_failure_rate=maximum(rates),
            minimum_adjacent_change=minimum_change,
            maximum_adjacent_change=maximum_change,
            nondecreasing=all(differences .>= 0.0),
            strictly_increasing=all(differences .> 0.0),
        ),
    )
end
comparisons = DataFrame(comparison_rows)

rates_path = output_prefix * "_rates.csv"
comparisons_path = output_prefix * "_monotonicity.csv"
summary_path = output_prefix * "_summary.txt"
mkpath(dirname(output_prefix))
CSV.write(rates_path, frame)
CSV.write(comparisons_path, comparisons)

open(summary_path, "w") do io
    println(io, "DD core statistical report")
    println(io, "input: $input_path")
    println(io, "rows: $(nrow(frame))")
    println(io, "matched parameter groups: $(nrow(comparisons))")
    println(
        io,
        "nondecreasing groups: $(sum(comparisons.nondecreasing)) / $(nrow(comparisons))",
    )
    println(
        io,
        "strictly increasing groups: $(sum(comparisons.strictly_increasing)) / $(nrow(comparisons))",
    )
    println(
        io,
        "groups with a decrease: $(sum(.!comparisons.nondecreasing))",
    )
    println(
        io,
        "largest 95% Wilson half-width: ",
        maximum((frame.failure_ci95_upper .- frame.failure_ci95_lower) ./ 2),
    )
    println(io)
    println(io, "Mean holdout failure rate by rho and withdrawal premium:")
    summary = combine(
        groupby(frame, [:rho, :withdrawal_premium]),
        :failure_rate => mean => :mean_failure_rate,
    )
    show(io, MIME("text/plain"), summary)
    println(io)
end

println("Wrote $rates_path")
println("Wrote $comparisons_path")
println("Wrote $summary_path")
