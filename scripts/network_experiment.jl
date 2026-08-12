using Distributed
using BankRunsFinal
using CSV
using DataFrames
using SHA
using Statistics
using TOML

function usage()
    println(
        """
        usage:
          network_experiment.jl init RUN_DIR [RUN_SEED]
          network_experiment.jl run STAGE RUN_DIR [--limit N] [--workers N]
          network_experiment.jl merge STAGE RUN_DIR
          network_experiment.jl freeze STAGE RUN_DIR
          network_experiment.jl set-draws RUN_DIR N
          network_experiment.jl adopt-selection-learning RUN_DIR
          network_experiment.jl select-adaptive RUN_DIR [--cells N]
          network_experiment.jl select-confirmatory RUN_DIR [--cells N]
          network_experiment.jl freeze-selection RUN_DIR
          network_experiment.jl adopt-monotonicity RUN_DIR
          network_experiment.jl prepare-monotonicity RUN_DIR
          network_experiment.jl freeze-monotonicity-design RUN_DIR
          network_experiment.jl status RUN_DIR

        STAGE is convergence, coverage, adaptive, confirmatory, or monotonicity.
        Adaptive accepts --batch N and --budget N.
        Confirmatory accepts --replications N.
        Monotonicity accepts --replications N.
        """,
    )
end

function option_value(args, name, default)
    position = findfirst(==(name), args)
    isnothing(position) && return default
    position < length(args) || error("$name requires a value")
    return args[position + 1]
end

manifest_path(run_directory) = joinpath(run_directory, "manifest.toml")

function source_fingerprint()
    repository = dirname(@__DIR__)
    files = sort!(
        vcat(
            filter(
                path -> endswith(path, ".jl"),
                readdir(joinpath(repository, "src"); join=true),
            ),
            [
                joinpath(repository, "scripts", "network_experiment.jl"),
                joinpath(repository, "Project.toml"),
                joinpath(repository, "Manifest.toml"),
            ],
        ),
    )
    file_hashes = [
        bytes2hex(sha256(read(file))) for file in files
    ]
    return bytes2hex(sha256(join(file_hashes, "\n")))
end

function initialize_run(run_directory::String, run_seed::UInt64)
    mkpath(run_directory)
    isfile(manifest_path(run_directory)) &&
        error("run already initialized: $run_directory")
    open(manifest_path(run_directory), "w") do io
        println(io, "run_seed = \"$(run_seed)\"")
        println(io, "agent_count = 1000")
        println(io, "reserve_ratios = [0.20, 0.30, 0.40]")
        println(io, "shock_sizes = [1, 10]")
        println(io, "shock_locations = [\"random\", \"localized\"]")
        println(io, "baseline_withdrawal_probability = 0.02")
        println(io, "selected_decision_draws = 200")
        println(io, "execution_model = \"large_sparse\"")
        println(io, "julia_version = \"$(VERSION)\"")
        println(io, "source_fingerprint = \"$(source_fingerprint())\"")
    end
    println("Initialized $run_directory")
end

function load_config(run_directory::String)
    manifest = TOML.parsefile(manifest_path(run_directory))
    recorded_fingerprint = String(manifest["source_fingerprint"])
    current_fingerprint = source_fingerprint()
    recorded_fingerprint == current_fingerprint ||
        error(
            "source fingerprint mismatch: run=$recorded_fingerprint " *
            "current=$current_fingerprint",
        )
    return NetworkExperimentConfig(
        RunSeed(parse(UInt64, manifest["run_seed"])),
        abspath(run_directory),
        Int(manifest["agent_count"]),
        Float64.(manifest["reserve_ratios"]),
        Int.(manifest["shock_sizes"]),
        Float64(manifest["baseline_withdrawal_probability"]),
        Int(manifest["selected_decision_draws"]),
    )
end

function adopt_selection_learning(run_directory::String)
    adaptive_marker = joinpath(
        run_directory,
        "adaptive",
        "batch_0001",
        "FROZEN",
    )
    isfile(adaptive_marker) ||
        error("adaptive batch 1 must be frozen before migration")
    confirmatory_marker = joinpath(
        run_directory,
        "confirmatory",
        "SELECTION_FROZEN",
    )
    !isfile(confirmatory_marker) ||
        error("cannot migrate after confirmatory selection is frozen")

    path = manifest_path(run_directory)
    manifest = TOML.parsefile(path)
    previous = String(manifest["source_fingerprint"])
    current = source_fingerprint()
    previous == current && return println("Source fingerprint already current")
    manifest["source_fingerprint"] = current
    temporary = path * ".tmp." * string(getpid())
    open(temporary, "w") do io
        TOML.print(io, manifest; sorted=true)
    end
    mv(temporary, path; force=true)

    migration = joinpath(run_directory, "SELECTION_LEARNING_MIGRATION")
    open(migration, "w") do io
        println(io, "previous_source_fingerprint=$previous")
        println(io, "current_source_fingerprint=$current")
        println(io, "scope=runner-only confirmatory selection learning")
        println(io, "adaptive_results=adaptive/batch_0001/results.csv")
    end
    println("Recorded selection-learning migration in $migration")
end

function adopt_monotonicity(run_directory::String)
    isfile(joinpath(run_directory, "confirmatory", "FROZEN")) ||
        error("confirmatory stage must be frozen before monotonicity migration")
    monotonicity_directory = joinpath(run_directory, "monotonicity")
    !isfile(joinpath(monotonicity_directory, "DESIGN_FROZEN")) ||
        error("cannot migrate after monotonicity design is frozen")
    isempty(chunk_files(joinpath(monotonicity_directory, "chunks"))) ||
        error("cannot migrate after monotonicity execution has started")

    path = manifest_path(run_directory)
    manifest = TOML.parsefile(path)
    previous = String(manifest["source_fingerprint"])
    current = source_fingerprint()
    previous == current && return println("Source fingerprint already current")
    manifest["source_fingerprint"] = current
    temporary = path * ".tmp." * string(getpid())
    open(temporary, "w") do io
        TOML.print(io, manifest; sorted=true)
    end
    mv(temporary, path; force=true)

    migration = joinpath(run_directory, "MONOTONICITY_MIGRATION")
    open(migration, "w") do io
        println(io, "previous_source_fingerprint=$previous")
        println(io, "current_source_fingerprint=$current")
        println(io, "scope=prespecified monotonicity stage")
        println(io, "predecessor=confirmatory/FROZEN")
    end
    println("Recorded monotonicity migration in $migration")
end

function stage_object(name::String, args=String[], config=nothing)
    name == "convergence" &&
        return ConvergenceStage([100, 200, 500, 1_000], 30)
    selected_draws = isnothing(config) ? 200 : config.decision_draws
    name == "coverage" && return CoverageStage(selected_draws, 5)
    name == "adaptive" && return AdaptiveStage(
        selected_draws,
        parse(Int, option_value(args, "--budget", "150000")),
        parse(Int, option_value(args, "--batch", "1")),
    )
    name == "confirmatory" && return ConfirmatoryStage(
        selected_draws,
        parse(Int, option_value(args, "--replications", "400")),
    )
    name == "monotonicity" && return MonotonicityStage(
        selected_draws,
        parse(Int, option_value(args, "--replications", "200")),
    )
    error("unsupported runnable stage: $name")
end

function set_selected_draws(run_directory::String, decision_draws::Int)
    decision_draws > 0 || error("decision draws must be positive")
    isfile(joinpath(run_directory, "convergence", "FROZEN")) ||
        error("freeze convergence before selecting draw depth")
    path = manifest_path(run_directory)
    manifest = TOML.parsefile(path)
    manifest["selected_decision_draws"] = decision_draws
    temporary = path * ".tmp." * string(getpid())
    open(temporary, "w") do io
        TOML.print(io, manifest; sorted=true)
    end
    mv(temporary, path; force=true)
    println("Selected decision_draws=$decision_draws in $path")
end

stage_directory(config, stage) =
    joinpath(config.run_directory, BankRunsFinal.stage_name(stage))

function chunk_files(directory::String)
    isdir(directory) || return String[]
    files = filter(
        path -> startswith(basename(path), "chunk_") &&
                endswith(path, ".csv"),
        readdir(directory; join=true),
    )
    sort!(files)
    return files
end

function completed_job_ids(directory::String)
    identifiers = Set{String}()
    for file in chunk_files(joinpath(directory, "chunks"))
        frame = CSV.read(file, DataFrame; select=[:job_id])
        union!(identifiers, String.(frame.job_id))
    end
    return identifiers
end

function selection_path(config, stage::AdaptiveStage)
    return joinpath(config.run_directory, "adaptive", "selection.csv")
end

function selection_path(config, stage::ConfirmatoryStage)
    return joinpath(config.run_directory, "confirmatory", "selection.csv")
end

function stage_jobs(
    config,
    stage::Union{ConvergenceStage,CoverageStage,MonotonicityStage},
)
    return experiment_jobs(config, stage)
end

function stage_jobs(config, stage::Union{AdaptiveStage,ConfirmatoryStage})
    path = selection_path(config, stage)
    isfile(path) || error("stage selection not found: $path")
    selection = CSV.read(path, DataFrame)
    return experiment_jobs(
        config,
        stage,
        Int.(selection.structural_index),
    )
end

function atomic_csv_write(destination::String, frame::DataFrame)
    mkpath(dirname(destination))
    temporary = destination * ".tmp." * string(getpid())
    CSV.write(temporary, frame)
    mv(temporary, destination; force=true)
    return destination
end

function next_chunk_index(directory::String)
    files = chunk_files(joinpath(directory, "chunks"))
    isempty(files) && return 1
    indices = [
        parse(Int, match(r"chunk_(\d+)\.csv$", basename(file)).captures[1])
        for file in files
    ]
    return maximum(indices) + 1
end

function ensure_workers(target_processes::Int)
    desired = max(1, target_processes)
    if nprocs() < desired
        addprocs(
            desired - nprocs();
            exeflags="--project=$(Base.active_project())",
        )
    end
    Distributed.remotecall_eval(Main, workers(), :(using BankRunsFinal))
end

function require_predecessor(config, stage::CoverageStage)
    marker = joinpath(config.run_directory, "convergence", "FROZEN")
    isfile(marker) ||
        error("coverage requires frozen convergence results: $marker")
end

require_predecessor(config, stage::ConvergenceStage) = nothing

function require_predecessor(config, stage::AdaptiveStage)
    marker = joinpath(config.run_directory, "coverage", "FROZEN")
    isfile(marker) || error("adaptive stage requires frozen coverage")
    isfile(selection_path(config, stage)) ||
        error("run select-adaptive before adaptive execution")
end

function require_predecessor(config, stage::ConfirmatoryStage)
    isfile(joinpath(config.run_directory, "confirmatory", "SELECTION_FROZEN")) ||
        error("run freeze-selection before confirmatory execution")
end

function monotonicity_design_paths(config)
    directory = joinpath(config.run_directory, "monotonicity")
    return (
        directory,
        joinpath(directory, "design.csv"),
        joinpath(directory, "hypotheses.csv"),
        joinpath(directory, "DESIGN_FROZEN"),
    )
end

function prepare_monotonicity(config)
    isfile(joinpath(config.run_directory, "confirmatory", "FROZEN")) ||
        error("freeze confirmatory results before preparing monotonicity")
    directory, design, hypotheses, marker =
        monotonicity_design_paths(config)
    !isfile(marker) || error("monotonicity design is already frozen")
    isempty(chunk_files(joinpath(directory, "chunks"))) ||
        error("cannot prepare design after monotonicity execution has started")
    atomic_csv_write(design, DataFrame(monotonicity_design_rows()))
    atomic_csv_write(
        hypotheses,
        DataFrame(monotonicity_hypothesis_rows()),
    )
    println("Prepared prespecified monotonicity design in $directory")
end

function freeze_monotonicity_design(config)
    directory, design, hypotheses, marker =
        monotonicity_design_paths(config)
    isfile(design) || error("prepare monotonicity design before freezing")
    isfile(hypotheses) || error("monotonicity hypotheses not found")
    isempty(chunk_files(joinpath(directory, "chunks"))) ||
        error("cannot freeze design after monotonicity execution has started")
    design_frame = CSV.read(design, DataFrame)
    hypothesis_frame = CSV.read(hypotheses, DataFrame)
    expected_design = DataFrame(monotonicity_design_rows())
    expected_hypotheses = DataFrame(monotonicity_hypothesis_rows())
    isequal(design_frame, expected_design) ||
        error("monotonicity design does not match the prespecified design")
    isequal(hypothesis_frame, expected_hypotheses) ||
        error(
            "monotonicity hypotheses do not match the prespecified hypotheses",
        )
    nrow(design_frame) == 66 ||
        error("expected 66 monotonicity design rows")
    length(unique(design_frame.structure_id)) == 6 ||
        error("expected six monotonicity structures")
    all(
        nrow(group) == 11
        for group in groupby(design_frame, :structure_id)
    ) || error("expected 11 settings per monotonicity structure")
    nrow(hypothesis_frame) == 3 ||
        error("expected three prespecified monotonicity hypotheses")
    open(marker, "w") do io
        println(io, "run_seed=$(config.run_seed.value)")
        println(io, "design_sha256=$(bytes2hex(sha256(read(design))))")
        println(
            io,
            "hypotheses_sha256=$(bytes2hex(sha256(read(hypotheses))))",
        )
        println(io, "structures=6")
        println(io, "settings_per_structure=11")
        println(io, "replications=200")
        println(io, "jobs=39600")
    end
    println("Froze monotonicity design in $directory")
end

function marker_value(path::String, key::String)
    prefix = key * "="
    for line in eachline(path)
        startswith(line, prefix) && return line[(length(prefix) + 1):end]
    end
    error("missing $key in $path")
end

function require_predecessor(config, stage::MonotonicityStage)
    isfile(joinpath(config.run_directory, "confirmatory", "FROZEN")) ||
        error("monotonicity stage requires frozen confirmatory results")
    _, design, hypotheses, marker = monotonicity_design_paths(config)
    isfile(marker) ||
        error("run freeze-monotonicity-design before monotonicity execution")
    bytes2hex(sha256(read(design))) ==
        marker_value(marker, "design_sha256") ||
        error("monotonicity design changed after it was frozen")
    bytes2hex(sha256(read(hypotheses))) ==
        marker_value(marker, "hypotheses_sha256") ||
        error("monotonicity hypotheses changed after they were frozen")
    recorded_replications =
        parse(Int, marker_value(marker, "replications"))
    stage.replications == recorded_replications ||
        error(
            "monotonicity design freezes $recorded_replications replications; " *
            "requested $(stage.replications)",
        )
end

function run_stage_command(
    config::NetworkExperimentConfig,
    stage::ExperimentStage;
    limit::Int=typemax(Int),
    target_processes::Int=min(Sys.CPU_THREADS, 16),
    chunk_size::Int=100,
)
    require_predecessor(config, stage)
    directory = stage_directory(config, stage)
    mkpath(joinpath(directory, "chunks"))
    jobs = stage_jobs(config, stage)
    completed = completed_job_ids(directory)
    pending = [
        job for job in jobs if !(job.job_id in completed)
    ]
    pending = pending[1:min(limit, length(pending))]
    println(
        "stage=$(BankRunsFinal.stage_name(stage)) total=$(length(jobs)) " *
        "completed=$(length(completed)) selected=$(length(pending))",
    )
    isempty(pending) && return

    ensure_workers(target_processes)
    chunk_index = next_chunk_index(directory)
    cursor = 1
    while cursor <= length(pending)
        final_index = min(cursor + chunk_size - 1, length(pending))
        batch = pending[cursor:final_index]
        results = pmap(run_experiment_job, batch; batch_size=1)
        frame = DataFrame(results)
        destination = joinpath(
            directory,
            "chunks",
            "chunk_" * lpad(string(chunk_index), 6, '0') * ".csv",
        )
        atomic_csv_write(destination, frame)
        println("Wrote $(nrow(frame)) results to $destination")
        cursor = final_index + 1
        chunk_index += 1
    end
end

function merge_stage(config, stage)
    directory = stage_directory(config, stage)
    files = chunk_files(joinpath(directory, "chunks"))
    isempty(files) && error("no chunks found for $(BankRunsFinal.stage_name(stage))")
    frames = [CSV.read(file, DataFrame) for file in files]
    frame = vcat(frames...; cols=:union)
    unique!(frame, :job_id)
    sort!(frame, :job_id)
    destination = joinpath(directory, "results.csv")
    atomic_csv_write(destination, frame)
    println("Merged $(nrow(frame)) unique jobs into $destination")
end

function freeze_stage(config, stage)
    directory = stage_directory(config, stage)
    results = joinpath(directory, "results.csv")
    isfile(results) || error("merge stage before freezing: $results")
    expected = length(stage_jobs(config, stage))
    observed = nrow(CSV.read(results, DataFrame; select=[:job_id]))
    observed == expected ||
        error("cannot freeze incomplete stage: expected $expected, found $observed")
    open(joinpath(directory, "FROZEN"), "w") do io
        println(io, "jobs=$observed")
        println(io, "run_seed=$(config.run_seed.value)")
    end
    println("Froze $(BankRunsFinal.stage_name(stage)) with $observed jobs")
end

function bernoulli_entropy(probability::Float64)
    p = clamp(probability, eps(), 1.0 - eps())
    return -p * log(p) - (1.0 - p) * log(1.0 - p)
end

const SELECTION_DESIGN_COLUMNS = [
    :deposit_model,
    :topology_model,
    :insurance_model,
    :reserve_ratio,
    :shock_size,
    :shock_location,
]

function score_adaptive_results(frame::DataFrame)
    required = vcat(
        [
            :structural_index,
            :decision_model,
            :failed,
            :elapsed_seconds,
        ],
        SELECTION_DESIGN_COLUMNS,
    )
    missing_columns = setdiff(required, propertynames(frame))
    isempty(missing_columns) ||
        error("adaptive results lack columns: $(join(missing_columns, ", "))")

    model_rows = NamedTuple[]
    for group in groupby(frame, [:structural_index, :decision_model])
        failures = sum(group.failed)
        trials = nrow(group)
        alpha = failures + 1.0
        beta = trials - failures + 1.0
        posterior_probability = alpha / (alpha + beta)
        posterior_sd = sqrt(
            alpha * beta /
            ((alpha + beta)^2 * (alpha + beta + 1.0)),
        )
        push!(
            model_rows,
            (
                structural_index=group.structural_index[1],
                decision_model=group.decision_model[1],
                trials,
                failures,
                posterior_probability,
                entropy=bernoulli_entropy(posterior_probability),
                posterior_sd,
                mean_runtime=mean(group.elapsed_seconds),
            ),
        )
    end

    model_scores = DataFrame(model_rows)
    score_rows = NamedTuple[]
    for group in groupby(model_scores, :structural_index)
        probabilities = group.posterior_probability
        disagreement = length(probabilities) > 1 ? std(probabilities) : 0.0
        mean_entropy = mean(group.entropy)
        uncertainty = mean(group.posterior_sd)
        runtime = mean(group.mean_runtime)
        learning_score =
            mean_entropy + disagreement + uncertainty - 0.02log1p(runtime)
        source = first(
            frame[frame.structural_index .== group.structural_index[1], :],
        )
        push!(
            score_rows,
            (
                structural_index=group.structural_index[1],
                learning_score,
                mean_entropy,
                disagreement,
                uncertainty,
                mean_runtime=runtime,
                replications_per_model=minimum(group.trials),
                deposit_model=source.deposit_model,
                topology_model=source.topology_model,
                insurance_model=source.insurance_model,
                reserve_ratio=source.reserve_ratio,
                shock_size=source.shock_size,
                shock_location=source.shock_location,
            ),
        )
    end
    scores = DataFrame(score_rows)
    sort!(scores, [:learning_score, :structural_index]; rev=[true, false])
    return scores
end

function diverse_confirmatory_selection(
    scores::DataFrame;
    cell_count::Int=80,
    diversity_weight::Float64=0.20,
)
    cell_count > 0 || throw(ArgumentError("cell_count must be positive"))
    diversity_weight >= 0 ||
        throw(ArgumentError("diversity_weight must be nonnegative"))
    selected_count = min(cell_count, nrow(scores))
    remaining = collect(1:nrow(scores))
    level_counts = Dict{Tuple{Symbol,Any},Int}()
    selected_rows = NamedTuple[]

    for rank in 1:selected_count
        best_position = 0
        best_score = -Inf
        best_bonus = 0.0
        best_structural_index = typemax(Int)
        for (position, row_index) in pairs(remaining)
            row = scores[row_index, :]
            bonus = mean(
                1.0 / (1.0 + get(level_counts, (column, row[column]), 0))
                for column in SELECTION_DESIGN_COLUMNS
            )
            selection_score = row.learning_score + diversity_weight * bonus
            structural_index = Int(row.structural_index)
            if selection_score > best_score ||
               (
                   selection_score == best_score &&
                   structural_index < best_structural_index
               )
                best_position = position
                best_score = selection_score
                best_bonus = bonus
                best_structural_index = structural_index
            end
        end

        row_index = remaining[best_position]
        row = scores[row_index, :]
        push!(
            selected_rows,
            merge(
                NamedTuple(row),
                (
                    selection_rank=rank,
                    diversity_bonus=best_bonus,
                    selection_score=best_score,
                ),
            ),
        )
        for column in SELECTION_DESIGN_COLUMNS
            key = (column, row[column])
            level_counts[key] = get(level_counts, key, 0) + 1
        end
        deleteat!(remaining, best_position)
    end
    return DataFrame(selected_rows)
end

function select_adaptive(config; cell_count::Int=100)
    coverage_directory = joinpath(config.run_directory, "coverage")
    isfile(joinpath(coverage_directory, "FROZEN")) ||
        error("coverage must be frozen before adaptive selection")
    frame = CSV.read(joinpath(coverage_directory, "results.csv"), DataFrame)
    model_rows = NamedTuple[]
    for group in groupby(frame, [:structural_index, :decision_model])
        failures = sum(group.failed)
        trials = nrow(group)
        posterior_probability = (failures + 1.0) / (trials + 2.0)
        push!(
            model_rows,
            (
                structural_index=group.structural_index[1],
                decision_model=group.decision_model[1],
                posterior_probability,
                entropy=bernoulli_entropy(posterior_probability),
                uncertainty=sqrt(
                    posterior_probability *
                    (1.0 - posterior_probability) /
                    (trials + 3.0),
                ),
                mean_runtime=mean(group.elapsed_seconds),
            ),
        )
    end
    model_scores = DataFrame(model_rows)
    score_rows = NamedTuple[]
    for group in groupby(model_scores, :structural_index)
        probabilities = group.posterior_probability
        disagreement = length(probabilities) > 1 ? std(probabilities) : 0.0
        mean_entropy = mean(group.entropy)
        uncertainty = mean(group.uncertainty)
        runtime = mean(group.mean_runtime)
        score =
            mean_entropy + disagreement + uncertainty - 0.02log1p(runtime)
        push!(
            score_rows,
            (
                structural_index=group.structural_index[1],
                score,
                mean_entropy,
                disagreement,
                uncertainty,
                mean_runtime=runtime,
            ),
        )
    end
    scores = DataFrame(score_rows)
    sort!(scores, :score; rev=true)
    selected_count = min(cell_count, nrow(scores))
    selection = first(scores, selected_count)
    adaptive_directory = joinpath(config.run_directory, "adaptive")
    atomic_csv_write(joinpath(adaptive_directory, "scores.csv"), scores)
    atomic_csv_write(
        joinpath(adaptive_directory, "selection.csv"),
        selection,
    )
    println(
        "Selected $selected_count high-entropy structural cells into " *
        joinpath(adaptive_directory, "selection.csv"),
    )
end

function select_confirmatory(config; cell_count::Int=80)
    adaptive_directory = joinpath(config.run_directory, "adaptive", "batch_0001")
    isfile(joinpath(adaptive_directory, "FROZEN")) ||
        error("freeze adaptive batch 1 before confirmatory selection")
    results = joinpath(adaptive_directory, "results.csv")
    isfile(results) || error("adaptive results not found: $results")
    scores = score_adaptive_results(CSV.read(results, DataFrame))
    selection = diverse_confirmatory_selection(scores; cell_count)

    destination_directory = joinpath(config.run_directory, "confirmatory")
    mkpath(destination_directory)
    atomic_csv_write(joinpath(destination_directory, "scores.csv"), scores)
    atomic_csv_write(
        joinpath(destination_directory, "selection.csv"),
        selection,
    )
    selection_path = joinpath(destination_directory, "selection.csv")
    println(
        "Learned $cell_count-cell confirmatory selection from adaptive results " *
        "into $selection_path",
    )
end

function freeze_selection(config)
    destination_directory = joinpath(config.run_directory, "confirmatory")
    source = joinpath(destination_directory, "selection.csv")
    scores = joinpath(destination_directory, "scores.csv")
    isfile(source) ||
        error("run select-confirmatory before freeze-selection: $source")
    isfile(scores) ||
        error("confirmatory selection scores not found: $scores")
    open(joinpath(destination_directory, "SELECTION_FROZEN"), "w") do io
        println(io, "run_seed=$(config.run_seed.value)")
        println(io, "source=adaptive/batch_0001/results.csv")
        println(io, "selection_sha256=$(bytes2hex(sha256(read(source))))")
        println(io, "scores_sha256=$(bytes2hex(sha256(read(scores))))")
    end
    println("Froze confirmatory selection in $destination_directory")
end

function status_command(config)
    println("run_directory=$(config.run_directory)")
    println("run_seed=$(config.run_seed.value)")
    for stage in (
        ConvergenceStage([100, 200, 500, 1_000], 30),
        CoverageStage(config.decision_draws, 5),
    )
        directory = stage_directory(config, stage)
        completed = length(completed_job_ids(directory))
        total = length(stage_jobs(config, stage))
        frozen = isfile(joinpath(directory, "FROZEN"))
        println(
            "$(BankRunsFinal.stage_name(stage)): $completed/$total frozen=$frozen",
        )
    end
    for stage in (
        AdaptiveStage(config.decision_draws, 150_000, 1),
        ConfirmatoryStage(config.decision_draws, 400),
        MonotonicityStage(config.decision_draws, 200),
    )
        directory = stage_directory(config, stage)
        selection_required =
            stage isa Union{AdaptiveStage,ConfirmatoryStage}
        selection_available =
            !selection_required || isfile(selection_path(config, stage))
        selection_available || continue
        completed = length(completed_job_ids(directory))
        total = length(stage_jobs(config, stage))
        frozen = isfile(joinpath(directory, "FROZEN"))
        println(
            "$(BankRunsFinal.stage_name(stage)): $completed/$total frozen=$frozen",
        )
    end
end

function main(args)
    isempty(args) && return usage()
    command = args[1]
    if command == "init"
        length(args) >= 2 || return usage()
        seed = length(args) >= 3 ? parse(UInt64, args[3]) : UInt64(20260723)
        return initialize_run(abspath(args[2]), seed)
    elseif command == "status"
        length(args) >= 2 || return usage()
        return status_command(load_config(abspath(args[2])))
    elseif command == "adopt-selection-learning"
        length(args) >= 2 || return usage()
        return adopt_selection_learning(abspath(args[2]))
    elseif command == "adopt-monotonicity"
        length(args) >= 2 || return usage()
        return adopt_monotonicity(abspath(args[2]))
    elseif command == "prepare-monotonicity"
        length(args) >= 2 || return usage()
        return prepare_monotonicity(load_config(abspath(args[2])))
    elseif command == "freeze-monotonicity-design"
        length(args) >= 2 || return usage()
        return freeze_monotonicity_design(
            load_config(abspath(args[2])),
        )
    elseif command == "select-adaptive"
        length(args) >= 2 || return usage()
        config = load_config(abspath(args[2]))
        cells = parse(Int, option_value(args, "--cells", "100"))
        return select_adaptive(config; cell_count=cells)
    elseif command == "select-confirmatory"
        length(args) >= 2 || return usage()
        config = load_config(abspath(args[2]))
        cells = parse(Int, option_value(args, "--cells", "80"))
        return select_confirmatory(config; cell_count=cells)
    elseif command == "freeze-selection"
        length(args) >= 2 || return usage()
        return freeze_selection(load_config(abspath(args[2])))
    elseif command == "set-draws"
        length(args) >= 3 || return usage()
        return set_selected_draws(abspath(args[2]), parse(Int, args[3]))
    elseif command in ("run", "merge", "freeze")
        length(args) >= 3 || return usage()
        config = load_config(abspath(args[3]))
        stage = stage_object(args[2], args, config)
        command == "merge" && return merge_stage(config, stage)
        command == "freeze" && return freeze_stage(config, stage)
        limit = parse(Int, option_value(args, "--limit", string(typemax(Int))))
        workers = parse(
            Int,
            option_value(args, "--workers", string(min(Sys.CPU_THREADS, 16))),
        )
        return run_stage_command(
            config,
            stage;
            limit,
            target_processes=workers,
        )
    end
    usage()
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    main(ARGS)
end
