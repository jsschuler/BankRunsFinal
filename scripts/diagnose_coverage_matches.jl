using CSV
using DataFrames
using Printf
using Statistics

const REQUIRED_MODELS = ["comparative", "threshold", "explicit_utility"]
const MATCH_KEYS = [:structural_index, :replication]
const SCENARIO_COLUMNS = [
    :deposit_model,
    :deposit_parameters,
    :topology_model,
    :topology_parameters,
    :insurance_model,
    :insurance_parameters,
    :reserve_ratio,
    :shock_size,
    :shock_location,
    :scenario_seed,
]

function require_columns(frame::DataFrame, columns)
    missing_columns = setdiff(columns, propertynames(frame))
    isempty(missing_columns) ||
        error("input is missing required columns: $(join(missing_columns, ", "))")
end

function validate_matches(frame::DataFrame)
    require_columns(
        frame,
        vcat(
            MATCH_KEYS,
            SCENARIO_COLUMNS,
            [
                :job_id,
                :decision_model,
                :failed,
                :endogenous_withdrawals,
                :total_withdrawals,
                :final_vault,
                :above_par_payments,
            ],
        ),
    )
    nrow(frame) == length(unique(frame.job_id)) ||
        error("job_id values are not unique")

    problems = String[]
    for group in groupby(frame, MATCH_KEYS)
        models = sort!(String.(group.decision_model))
        models == sort(REQUIRED_MODELS) ||
            push!(
                problems,
                "structural_index=$(group.structural_index[1]), " *
                "replication=$(group.replication[1]) has models=$(join(models, "|"))",
            )
        for column in SCENARIO_COLUMNS
            length(unique(group[!, column])) == 1 ||
                push!(
                    problems,
                    "structural_index=$(group.structural_index[1]), " *
                    "replication=$(group.replication[1]) differs on $column",
                )
        end
        length(problems) >= 10 && break
    end
    isempty(problems) ||
        error("invalid matched scenarios:\n" * join(problems, "\n"))
end

function comparison_rows(frame::DataFrame)
    text_value(value) = ismissing(value) ? "" : String(value)
    indexed = Dict(
        (row.structural_index, row.replication, String(row.decision_model)) =>
            row for row in eachrow(frame)
    )
    rows = NamedTuple[]
    for group in groupby(frame, MATCH_KEYS)
        structural_index = group.structural_index[1]
        replication = group.replication[1]
        comparative = indexed[(structural_index, replication, "comparative")]
        for comparator_name in ("threshold", "explicit_utility")
            comparator = indexed[(structural_index, replication, comparator_name)]
            withdrawal_difference =
                comparative.total_withdrawals - comparator.total_withdrawals
            vault_difference = comparative.final_vault - comparator.final_vault
            push!(
                rows,
                (
                    structural_index,
                    replication,
                    deposit_model=text_value(comparative.deposit_model),
                    deposit_parameters=text_value(comparative.deposit_parameters),
                    topology_model=text_value(comparative.topology_model),
                    topology_parameters=text_value(comparative.topology_parameters),
                    insurance_model=text_value(comparative.insurance_model),
                    insurance_parameters=text_value(comparative.insurance_parameters),
                    reserve_ratio=comparative.reserve_ratio,
                    shock_size=comparative.shock_size,
                    shock_location=String(comparative.shock_location),
                    scenario_seed=comparative.scenario_seed,
                    comparator_model=comparator_name,
                    comparative_failed=comparative.failed,
                    comparator_failed=comparator.failed,
                    comparative_endogenous=comparative.endogenous_withdrawals,
                    comparator_endogenous=comparator.endogenous_withdrawals,
                    comparative_total=comparative.total_withdrawals,
                    comparator_total=comparator.total_withdrawals,
                    comparative_final_vault=comparative.final_vault,
                    comparator_final_vault=comparator.final_vault,
                    withdrawal_difference,
                    vault_difference,
                    comparative_only_failure=
                        comparative.failed && !comparator.failed,
                    comparator_only_failure=
                        !comparative.failed && comparator.failed,
                    more_withdrawals_and_more_vault=
                        withdrawal_difference > 0 && vault_difference > 0.0,
                ),
            )
        end
    end
    return DataFrame(rows)
end

function rate(values)
    isempty(values) && return NaN
    return mean(values)
end

function matched_summary(comparisons::DataFrame)
    return combine(
        groupby(comparisons, [:comparator_model]),
        nrow => :matched_runs,
        :comparative_only_failure => sum => :comparative_only_failures,
        :comparator_only_failure => sum => :comparator_only_failures,
        :more_withdrawals_and_more_vault => sum =>
            :more_withdrawals_and_more_vault,
        :withdrawal_difference => mean => :mean_withdrawal_difference,
        :vault_difference => mean => :mean_vault_difference,
    )
end

function stratum_summary(comparisons::DataFrame)
    return combine(
        groupby(
            comparisons,
            [:deposit_model, :insurance_model, :comparator_model],
        ),
        nrow => :matched_runs,
        :comparative_failed => mean => :comparative_failure_rate,
        :comparator_failed => mean => :comparator_failure_rate,
        :comparator_only_failure => sum => :comparator_only_failures,
        :more_withdrawals_and_more_vault => mean =>
            :more_withdrawals_and_more_vault_rate,
        :withdrawal_difference => mean => :mean_withdrawal_difference,
        :vault_difference => mean => :mean_vault_difference,
    )
end

function near_depletion_summary(frame::DataFrame)
    working = select(
        frame,
        :deposit_model,
        :decision_model,
        :failed,
        :final_vault,
    )
    working.vault_below_1 = working.final_vault .< 1.0
    working.vault_below_10 = working.final_vault .< 10.0
    working.vault_below_20 = working.final_vault .< 20.0
    return combine(
        groupby(working, [:deposit_model, :decision_model]),
        nrow => :runs,
        :failed => sum => :failures,
        :final_vault => minimum => :minimum_final_vault,
        :vault_below_1 => sum => :vault_below_1,
        :vault_below_10 => sum => :vault_below_10,
        :vault_below_20 => sum => :vault_below_20,
    )
end

function write_report(
    path::String,
    input_path::String,
    frame::DataFrame,
    comparisons::DataFrame,
    summary::DataFrame,
    strata::DataFrame,
    near_depletion::DataFrame,
)
    heterogeneous = comparisons.deposit_model .!= "homogeneous"
    homogeneous = .!heterogeneous
    divergent = comparisons.comparator_only_failure
    hetero_divergent = divergent .& heterogeneous
    homo_divergent = divergent .& homogeneous
    diagnostic_pattern = comparisons.more_withdrawals_and_more_vault

    open(path, "w") do io
        println(io, "# Matched coverage diagnostic")
        println(io)
        println(io, "- Input: `$input_path`")
        println(io, "- Coverage jobs: $(nrow(frame))")
        println(io, "- Matched scenario/replication groups: $(nrow(frame) ÷ 3)")
        println(io, "- Pairwise comparative-model contrasts: $(nrow(comparisons))")
        println(io, "- Above-par payment flags: $(sum(frame.above_par_payments))")
        println(io)
        println(io, "## Main result")
        println(io)
        println(
            io,
            "The comparative model survived while its comparator failed in " *
            "$(sum(divergent)) pairwise matches. Of these, " *
            "$(sum(hetero_divergent)) used heterogeneous deposits and " *
            "$(sum(homo_divergent)) used homogeneous deposits.",
        )
        println(
            io,
            "Across all contrasts, the comparative model made more withdrawals " *
            "while retaining more vault value in $(sum(diagnostic_pattern)) " *
            "matches ($(round(100 * rate(diagnostic_pattern); digits=2))%).",
        )
        if any(divergent)
            divergent_pattern = diagnostic_pattern[divergent]
            println(
                io,
                "Within comparator-only failures, that pattern occurred in " *
                "$(sum(divergent_pattern)) of $(sum(divergent)) matches " *
                "($(round(100 * rate(divergent_pattern); digits=2))%).",
            )
        end
        println(io)
        println(io, "This pattern means withdrawal counts alone do not explain bank")
        println(io, "failure: the identity and insured payment of withdrawing agents")
        println(io, "materially change vault depletion. It supports a claim-size")
        println(io, "selection mechanism, but does not by itself establish that the")
        println(io, "underlying decision rule is economically correct.")
        println(io)
        heterogeneous_comparative = frame[
            (frame.deposit_model .!= "homogeneous") .&
            (frame.decision_model .== "comparative"),
            :,
        ]
        minimum_vault_text =
            @sprintf("%.9f", minimum(heterogeneous_comparative.final_vault))
        println(io, "## Failure-boundary diagnostic")
        println(io)
        println(
            io,
            "The comparative model has zero recorded failures in " *
            "$(nrow(heterogeneous_comparative)) heterogeneous-deposit runs, but " *
            "its minimum final vault is $minimum_vault_text.",
        )
        println(
            io,
            "$(sum(heterogeneous_comparative.final_vault .< 1.0)) of those runs " *
            "finish with less than 1 unit in the vault, and " *
            "$(sum(heterogeneous_comparative.final_vault .< 20.0)) finish with " *
            "less than 20.",
        )
        println(
            io,
            "Because `failed` is defined as `final_vault <= 0`, continuous " *
            "heterogeneous deposits can leave an arbitrarily small positive " *
            "residual and still be classified as survival. This exact boundary " *
            "contributes to the sharp zero-failure result and should be reported " *
            "alongside near-depletion outcomes.",
        )
        println(io)
        println(io, "## Pairwise summary")
        println(io)
        println(io, "```text")
        show(io, MIME("text/plain"), summary)
        println(io)
        println(io, "```")
        println(io)
        println(io, "## Deposit and insurance strata")
        println(io)
        println(io, "```text")
        show(io, MIME("text/plain"), strata; allrows=true, allcols=true)
        println(io)
        println(io, "```")
        println(io)
        println(io, "## Near-depletion summary")
        println(io)
        println(io, "```text")
        show(io, MIME("text/plain"), near_depletion; allrows=true, allcols=true)
        println(io)
        println(io, "```")
    end
end

length(ARGS) >= 1 || error(
    "usage: julia --project=. scripts/diagnose_coverage_matches.jl " *
    "COVERAGE.csv [OUTPUT_PREFIX]",
)

input_path = abspath(ARGS[1])
output_prefix =
    length(ARGS) >= 2 ?
    abspath(ARGS[2]) :
    splitext(input_path)[1] * "_matched_diagnostic"

frame = CSV.read(input_path, DataFrame)
validate_matches(frame)
comparisons = comparison_rows(frame)
summary = matched_summary(comparisons)
strata = stratum_summary(comparisons)
sort!(strata, [:deposit_model, :insurance_model, :comparator_model])
near_depletion = near_depletion_summary(frame)
sort!(near_depletion, [:deposit_model, :decision_model])

mkpath(dirname(output_prefix))
comparisons_path = output_prefix * "_pairs.csv"
strata_path = output_prefix * "_strata.csv"
near_depletion_path = output_prefix * "_near_depletion.csv"
report_path = output_prefix * "_report.md"
CSV.write(comparisons_path, comparisons)
CSV.write(strata_path, strata)
CSV.write(near_depletion_path, near_depletion)
write_report(
    report_path,
    input_path,
    frame,
    comparisons,
    summary,
    strata,
    near_depletion,
)

println("Validated $(nrow(frame) ÷ 3) complete matched scenarios")
println("Wrote $comparisons_path")
println("Wrote $strata_path")
println("Wrote $near_depletion_path")
println("Wrote $report_path")
