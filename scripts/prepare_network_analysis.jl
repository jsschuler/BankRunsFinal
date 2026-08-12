using CSV
using DataFrames
using Statistics

length(ARGS) >= 1 ||
    error("usage: julia --project=. scripts/prepare_network_analysis.jl RUN_DIR [OUTPUT_DIR]")

run_directory = abspath(ARGS[1])
output_directory =
    length(ARGS) >= 2 ? abspath(ARGS[2]) :
    joinpath(dirname(@__DIR__), "output", "network_analysis_seed20260723")

confirmatory_path = joinpath(run_directory, "confirmatory", "results.csv")
monotonicity_path = joinpath(run_directory, "monotonicity", "results.csv")
design_path = joinpath(run_directory, "monotonicity", "design.csv")
hypotheses_path = joinpath(run_directory, "monotonicity", "hypotheses.csv")
validation_path =
    joinpath(dirname(@__DIR__), "output", "network_validation_seed20260723.csv")

for path in (
    confirmatory_path,
    monotonicity_path,
    design_path,
    hypotheses_path,
    validation_path,
)
    isfile(path) || error("required input not found: $path")
end
for marker in (
    joinpath(run_directory, "confirmatory", "FROZEN"),
    joinpath(run_directory, "monotonicity", "DESIGN_FROZEN"),
    joinpath(run_directory, "monotonicity", "FROZEN"),
)
    isfile(marker) || error("required freeze marker not found: $marker")
end

confirmatory = CSV.read(confirmatory_path, DataFrame)
monotonicity = CSV.read(monotonicity_path, DataFrame)
design = CSV.read(design_path, DataFrame)
hypotheses = CSV.read(hypotheses_path, DataFrame)
validation = CSV.read(validation_path, DataFrame)

function require_columns(frame, columns, label)
    missing_columns = setdiff(columns, propertynames(frame))
    isempty(missing_columns) ||
        error("$label is missing columns: $(join(missing_columns, ", "))")
end

result_columns = [
    :job_id,
    :structural_index,
    :replication,
    :decision_model,
    :scenario_seed,
    :model_seed,
    :failed,
    :endogenous_withdrawals,
    :total_withdrawals,
    :final_vault,
    :rounds,
    :elapsed_seconds,
    :above_par_payments,
]
require_columns(confirmatory, result_columns, "confirmatory results")
require_columns(monotonicity, result_columns, "monotonicity results")
require_columns(
    design,
    [:structural_index, :structure_id, :structure_label, :path, :level],
    "monotonicity design",
)

function check_results(frame, label, expected_rows)
    nrow(frame) == expected_rows ||
        error("$label has $(nrow(frame)) rows; expected $expected_rows")
    length(unique(frame.job_id)) == expected_rows ||
        error("$label contains duplicate job IDs")
    analysis_columns = [
        :job_id,
        :structural_index,
        :replication,
        :decision_model,
        :scenario_seed,
        :model_seed,
        :failed,
        :endogenous_withdrawals,
        :total_withdrawals,
        :final_vault,
        :rounds,
        :elapsed_seconds,
        :above_par_payments,
    ]
    any(
        column -> any(ismissing, frame[!, column]),
        analysis_columns,
    ) && error("$label contains missing analysis values")
    all(frame.above_par_payments .== 0) ||
        error("$label contains above-par payments")
end

check_results(confirmatory, "confirmatory results", 96_000)
check_results(monotonicity, "monotonicity results", 39_600)
nrow(design) == 66 || error("monotonicity design has $(nrow(design)) rows; expected 66")
nrow(hypotheses) == 3 ||
    error("monotonicity hypotheses has $(nrow(hypotheses)) rows; expected 3")
nrow(validation) == 1_800 ||
    error("validation results has $(nrow(validation)) rows; expected 1800")
length(unique(collect(zip(validation.job_index, validation.model)))) == 1_800 ||
    error("validation results contain duplicate job/model pairs")
any(column -> any(ismissing, column), eachcol(validation)) &&
    error("validation results contain missing values")
all(validation.above_par_payments .== 0) ||
    error("validation results contain above-par payments")

function summarize_results(frame, group_columns)
    summary = combine(
        groupby(frame, group_columns),
        nrow => :replications,
        :failed => (x -> count(identity, x)) => :failure_count,
        :failed => mean => :failure_rate,
        :endogenous_withdrawals => mean => :mean_endogenous_withdrawals,
        :total_withdrawals => mean => :mean_total_withdrawals,
        :final_vault => mean => :mean_final_vault,
        :rounds => mean => :mean_rounds,
        :elapsed_seconds => mean => :mean_elapsed_seconds,
    )
    sort!(summary, group_columns)
    return summary
end

confirmatory_groups = [
    :structural_index,
    :deposit_model,
    :deposit_parameters,
    :topology_model,
    :topology_parameters,
    :insurance_model,
    :insurance_parameters,
    :reserve_ratio,
    :shock_size,
    :shock_location,
    :decision_model,
]
confirmatory_summary = summarize_results(confirmatory, confirmatory_groups)

monotonicity_annotated = leftjoin(
    monotonicity,
    select(design, :structural_index, :structure_id, :structure_label, :path, :level);
    on=:structural_index,
    validate=(false, true),
)
any(ismissing, monotonicity_annotated.structure_id) &&
    error("some monotonicity results did not match the frozen design")
monotonicity_groups = [
    :structure_id,
    :structure_label,
    :structural_index,
    :path,
    :level,
    :decision_model,
]
monotonicity_summary =
    summarize_results(monotonicity_annotated, monotonicity_groups)

validation_summary = combine(
    groupby(validation, [:reserve_ratio, :initial_count, :model]),
    nrow => :replications,
    :failed => (x -> count(identity, x)) => :failure_count,
    :failed => mean => :failure_rate,
    :endogenous_withdrawals => mean => :mean_endogenous_withdrawals,
    :total_withdrawals => mean => :mean_total_withdrawals,
    :final_vault => mean => :mean_final_vault,
    :rounds => mean => :mean_rounds,
)
sort!(validation_summary, [:reserve_ratio, :initial_count, :model])

mkpath(output_directory)
confirmatory_output = joinpath(output_directory, "confirmatory_cell_summary.csv")
monotonicity_output = joinpath(output_directory, "monotonicity_cell_summary.csv")
validation_output = joinpath(output_directory, "validation_summary.csv")
hypotheses_output = joinpath(output_directory, "monotonicity_hypotheses.csv")
report_output = joinpath(output_directory, "integrity_report.txt")

CSV.write(confirmatory_output, confirmatory_summary)
CSV.write(monotonicity_output, monotonicity_summary)
CSV.write(validation_output, validation_summary)
CSV.write(hypotheses_output, hypotheses)

open(report_output, "w") do io
    println(io, "Frozen network experiment integrity report")
    println(io, "run directory: $run_directory")
    println(io)
    println(io, "confirmatory rows: $(nrow(confirmatory))")
    println(io, "confirmatory unique jobs: $(length(unique(confirmatory.job_id)))")
    println(io, "confirmatory summary cells: $(nrow(confirmatory_summary))")
    println(io, "confirmatory failed outcomes: $(count(identity, confirmatory.failed))")
    println(io)
    println(io, "monotonicity rows: $(nrow(monotonicity))")
    println(io, "monotonicity unique jobs: $(length(unique(monotonicity.job_id)))")
    println(io, "monotonicity design rows: $(nrow(design))")
    println(io, "monotonicity hypotheses: $(nrow(hypotheses))")
    println(io, "monotonicity summary cells: $(nrow(monotonicity_summary))")
    println(io, "monotonicity failed outcomes: $(count(identity, monotonicity.failed))")
    println(io)
    println(io, "validation rows: $(nrow(validation))")
    println(io, "validation summary cells: $(nrow(validation_summary))")
    println(io, "validation failed outcomes: $(count(identity, validation.failed))")
    println(io)
    println(io, "Checks passed:")
    println(io, "- required inputs and freeze markers exist")
    println(io, "- expected row counts match")
    println(io, "- job identifiers are unique")
    println(io, "- required identifiers and analysis values are nonmissing")
    println(io, "- missing values are confined to not-applicable parameter fields")
    println(io, "- above-par payment counts are zero")
    println(io, "- monotonicity results join completely to the frozen design")
end

println("Wrote $confirmatory_output")
println("Wrote $monotonicity_output")
println("Wrote $validation_output")
println("Wrote $hypotheses_output")
println("Wrote $report_output")
