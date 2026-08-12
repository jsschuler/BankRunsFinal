using BankRunsFinal
using CSV
using DataFrames
using Random
using Statistics
using TOML

function usage()
    println(
        """
        usage:
          initial_condition_sensitivity.jl run RUN_DIR [--cells N] \
[--structures N] [--shocks N] [--output PATH]
          initial_condition_sensitivity.jl report RESULTS.csv [REPORT_PREFIX]

        The run command holds deposits and the graph fixed within each
        structural realization, varies only initial-shock membership, and uses
        matched shocks and model seeds across all three decision models.
        """,
    )
end

function option_value(args, name, default)
    position = findfirst(==(name), args)
    isnothing(position) && return default
    position < length(args) || error("$name requires a value")
    return args[position + 1]
end

function load_config(run_directory::String)
    manifest = TOML.parsefile(joinpath(run_directory, "manifest.toml"))
    return NetworkExperimentConfig(
        RunSeed(parse(UInt64, manifest["run_seed"])),
        run_directory,
        Int(manifest["agent_count"]),
        Float64.(manifest["reserve_ratios"]),
        Int.(manifest["shock_sizes"]),
        Float64(manifest["baseline_withdrawal_probability"]),
        Int(manifest["selected_decision_draws"]),
    )
end

function bernoulli_entropy(probability::Real)
    p = clamp(Float64(probability), eps(), 1.0 - eps())
    return -p * log(p) - (1.0 - p) * log(1.0 - p)
end

function select_candidate_cells(frame::DataFrame, cell_count::Int)
    model_rows = NamedTuple[]
    for group in groupby(frame, [:structural_index, :decision_model])
        failure_rate = mean(group.failed)
        push!(
            model_rows,
            (
                structural_index=group.structural_index[1],
                decision_model=String(group.decision_model[1]),
                failure_rate,
                failure_entropy=bernoulli_entropy(
                    (sum(group.failed) + 1) / (nrow(group) + 2),
                ),
                mixed_outcome=0.0 < failure_rate < 1.0,
                withdrawal_sd=std(group.total_withdrawals; corrected=false),
            ),
        )
    end
    model_frame = DataFrame(model_rows)
    maximum_sd = max(maximum(model_frame.withdrawal_sd), eps())
    rows = NamedTuple[]
    for group in groupby(model_frame, :structural_index)
        disagreement = std(group.failure_rate; corrected=false)
        score =
            mean(group.failure_entropy) +
            disagreement +
            mean(group.mixed_outcome) +
            0.25mean(group.withdrawal_sd) / maximum_sd
        push!(
            rows,
            (
                structural_index=group.structural_index[1],
                score,
                mixed_models=sum(group.mixed_outcome),
                model_disagreement=disagreement,
                mean_withdrawal_sd=mean(group.withdrawal_sd),
            ),
        )
    end
    scores = DataFrame(rows)
    sort!(scores, :score; rev=true)
    return first(scores, min(cell_count, nrow(scores)))
end

decision_specifications() = DecisionSpecification[
    ComparativeDecisionSpecification(),
    ThresholdDecisionSpecification(0.80),
    ExplicitUtilityDecisionSpecification(1.0, 1.25),
]

decision_name(::ComparativeDecisionSpecification) = "comparative"
decision_name(::ThresholdDecisionSpecification) = "threshold"
decision_name(::ExplicitUtilityDecisionSpecification) = "explicit_utility"

function run_sensitivity(
    config::NetworkExperimentConfig,
    selected::DataFrame,
    structure_replications::Int,
    shock_replications::Int,
)
    template_jobs = experiment_jobs(
        config,
        CoverageStage(config.decision_draws, 1),
    )
    templates = Dict(
        job.structural_index => job for job in template_jobs if
        job.decision_specification isa ComparativeDecisionSpecification
    )
    rows = NamedTuple[]
    rows_lock = ReentrantLock()
    completed = Threads.Atomic{Int}(0)
    total_models =
        nrow(selected) * structure_replications * shock_replications * 3
    for selection in eachrow(selected)
        structural_index = selection.structural_index
        template = templates[structural_index]
        for structure_replication in 1:structure_replications
            structure_seed = derive_seed(
                config.run_seed,
                20,
                structural_index,
                structure_replication,
            )
            structure_rng = Xoshiro(structure_seed)
            deposits = generate_deposits(
                structure_rng,
                template.deposit_specification,
                config.agent_count,
            )
            graph = generate_graph(
                structure_rng,
                template.topology_specification,
                config.agent_count,
            )
            insurance =
                resolve_insurance(template.insurance_specification, deposits)
            Threads.@threads for shock_replication in 1:shock_replications
                shock_seed = derive_seed(
                    config.run_seed,
                    21,
                    structural_index,
                    structure_replication,
                    shock_replication,
                )
                shock_rng = Xoshiro(shock_seed)
                initial_withdrawals = select_initial_withdrawals(
                    shock_rng,
                    graph,
                    template.shock_size,
                    template.shock_location,
                )
                model_seed = derive_seed(
                    config.run_seed,
                    22,
                    structural_index,
                    structure_replication,
                    shock_replication,
                )
                scenario = NetworkScenario(
                    graph,
                    deposits,
                    template.reserve_ratio,
                    insurance,
                    initial_withdrawals,
                    config.baseline_withdrawal_probability,
                    config.decision_draws,
                )
                for decision in decision_specifications()
                    model = LargeSparseNetworkModel(
                        BankRunsFinal.economic_model(decision, scenario),
                    )
                    elapsed = @elapsed result =
                        run_network_model(model, RunSeed(model_seed))
                    row = (
                            structural_index,
                            structure_replication,
                            shock_replication,
                            structure_seed,
                            shock_seed,
                            model_seed,
                            initial_withdrawals=join(
                                sort(initial_withdrawals),
                                ";",
                            ),
                            deposit_model=BankRunsFinal.deposit_name(
                                template.deposit_specification,
                            ),
                            topology_model=BankRunsFinal.topology_name(
                                template.topology_specification,
                            ),
                            insurance_model=BankRunsFinal.insurance_name(
                                template.insurance_specification,
                            ),
                            reserve_ratio=template.reserve_ratio,
                            shock_size=template.shock_size,
                            shock_location=BankRunsFinal.shock_name(
                                template.shock_location,
                            ),
                            decision_model=decision_name(decision),
                            failed=result.failed,
                            endogenous_withdrawals=result.endogenous_withdrawals,
                            total_withdrawals=result.total_withdrawals,
                            final_vault=result.final_vault,
                            rounds=result.rounds,
                            elapsed_seconds=elapsed,
                        )
                    lock(rows_lock) do
                        push!(rows, row)
                    end
                    completed_now = Threads.atomic_add!(completed, 1) + 1
                    completed_now % 100 == 0 && println(
                        "Completed $completed_now / $total_models models",
                    )
                end
            end
        end
    end
    frame = DataFrame(rows)
    sort!(
        frame,
        [
            :structural_index,
            :structure_replication,
            :shock_replication,
            :decision_model,
        ],
    )
    return frame
end

function sensitivity_summary(frame::DataFrame)
    cell_rows = NamedTuple[]
    keys = [:structural_index, :structure_replication, :decision_model]
    for group in groupby(frame, keys)
        rate = mean(group.failed)
        push!(
            cell_rows,
            (
                structural_index=group.structural_index[1],
                structure_replication=group.structure_replication[1],
                decision_model=group.decision_model[1],
                shock_trials=nrow(group),
                failure_rate=rate,
                outcome_flip=0.0 < rate < 1.0,
                minimum_total_withdrawals=minimum(group.total_withdrawals),
                maximum_total_withdrawals=maximum(group.total_withdrawals),
                withdrawal_range=
                    maximum(group.total_withdrawals) -
                    minimum(group.total_withdrawals),
                withdrawal_sd=std(
                    group.total_withdrawals;
                    corrected=false,
                ),
            ),
        )
    end
    return DataFrame(cell_rows)
end

function write_report(frame::DataFrame, prefix::String)
    summary = sensitivity_summary(frame)
    summary_path = prefix * "_cells.csv"
    report_path = prefix * "_report.md"
    CSV.write(summary_path, summary)
    open(report_path, "w") do io
        println(io, "# Initial-condition sensitivity diagnostic")
        println(io)
        println(io, "- Model runs: $(nrow(frame))")
        println(
            io,
            "- Fixed structure/model cells: $(nrow(summary))",
        )
        println(
            io,
            "- Cells with failure outcome flips across shock membership: " *
            "$(sum(summary.outcome_flip))",
        )
        println(
            io,
            "- Structural realizations with at least one model flip: " *
            "$(length(Set(zip(
                summary.structural_index[summary.outcome_flip],
                summary.structure_replication[summary.outcome_flip],
            ))))",
        )
        println(
            io,
            "- Median within-cell withdrawal range: " *
            "$(median(summary.withdrawal_range))",
        )
        println(
            io,
            "- Maximum within-cell withdrawal range: " *
            "$(maximum(summary.withdrawal_range))",
        )
        println(io)
        println(io, "A cell-level outcome flip is the knife-edge estimand: with")
        println(io, "the graph, deposits, parameters, and model fixed, changing")
        println(io, "only the initially withdrawing agents changes bank failure.")
        println(io)
        println(io, "## Cell summary")
        println(io)
        println(io, "```text")
        show(io, MIME("text/plain"), summary; allrows=true, allcols=true)
        println(io)
        println(io, "```")
    end
    println("Wrote $summary_path")
    println("Wrote $report_path")
end

function main(args)
    isempty(args) && return usage()
    if args[1] == "run"
        length(args) >= 2 || return usage()
        run_directory = abspath(args[2])
        cell_count = parse(Int, option_value(args, "--cells", "20"))
        structure_replications =
            parse(Int, option_value(args, "--structures", "3"))
        shock_replications =
            parse(Int, option_value(args, "--shocks", "50"))
        output_path = abspath(
            option_value(
                args,
                "--output",
                joinpath(
                    run_directory,
                    "initial_conditions",
                    "results.csv",
                ),
            ),
        )
        config = load_config(run_directory)
        coverage = CSV.read(
            joinpath(run_directory, "coverage", "results.csv"),
            DataFrame,
        )
        selected = select_candidate_cells(coverage, cell_count)
        mkpath(dirname(output_path))
        CSV.write(
            joinpath(dirname(output_path), "selection.csv"),
            selected,
        )
        results = run_sensitivity(
            config,
            selected,
            structure_replications,
            shock_replications,
        )
        CSV.write(output_path, results)
        println("Wrote $output_path")
        write_report(results, splitext(output_path)[1])
    elseif args[1] == "report"
        length(args) >= 2 || return usage()
        input_path = abspath(args[2])
        prefix =
            length(args) >= 3 ?
            abspath(args[3]) :
            splitext(input_path)[1]
        write_report(CSV.read(input_path, DataFrame), prefix)
    else
        usage()
    end
end

main(ARGS)
