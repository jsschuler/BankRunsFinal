using Distributed
using BankRunsFinal
using CSV
using DataFrames
using SHA
using TOML

const RUN_SEED = RunSeed(20260724)
const PREMIA = (0.0, 0.005, 0.01, 0.02, 0.05, 0.10, 0.25, 0.50)
const PRODUCTIVITIES = (0.25, 0.50, 0.75, 1.00)
const RHOS = (0.0, 0.5, 1.0, 2.0)
const SHIFTS = (0.1, 1.0, 10.0, 100.0)

function utility_specs(; shifts=SHIFTS)
    specs = Tuple{Float64,Float64}[(0.0, 1.0)]
    for rho in (0.5, 1.0, 2.0), shift in shifts
        push!(specs, (rho, shift))
    end
    return specs
end

function make_jobs(
    probabilities,
    specs;
    premia=PREMIA,
    productivities=PRODUCTIVITIES,
    config,
)
    jobs = DDJob[]
    index = 0
    for (rho, shift) in specs,
        premium in premia,
        productivity in productivities,
        probability in probabilities
        index += 1
        push!(
            jobs,
            DDJob(
                index,
                RUN_SEED,
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

function panel_design(panel::String)
    if panel == "allocation_main"
        config = DDConfig(
            agent_count=50,
            decision_draws=100,
            search_realizations=1_000,
            evaluation_realizations=10_000,
            total_resources=1_000,
            allocation_step=10,
        )
        jobs = make_jobs(
            0.02:0.02:1.0,
            [(rho, 1.0) for rho in RHOS];
            config,
        )
        return jobs, config, 16
    elseif panel == "allocation_shift"
        config = DDConfig(
            agent_count=50,
            decision_draws=100,
            search_realizations=1_000,
            evaluation_realizations=10_000,
            total_resources=1_000,
            allocation_step=10,
        )
        jobs = make_jobs(
            0.05:0.05:1.0,
            utility_specs(shifts=(0.1, 10.0, 100.0))[2:end];
            premia=(0.01, 0.05, 0.10, 0.50),
            productivities=(0.50, 1.00),
            config,
        )
        return jobs, config, 16
    elseif panel == "fixed_sensitivity"
        config = DDConfig(
            agent_count=50,
            decision_draws=100,
            search_realizations=1,
            evaluation_realizations=10_000,
            total_resources=1_000,
            allocation_step=10,
        )
        jobs = make_jobs(
            0.01:0.01:1.0,
            utility_specs();
            config,
        )
        return jobs, config, 32
    end
    throw(ArgumentError("unknown panel: $panel"))
end

function design_record(panel, jobs, config, chunk_size)
    return Dict(
        "panel" => panel,
        "run_seed" => string(RUN_SEED.value),
        "job_count" => length(jobs),
        "chunk_size" => chunk_size,
        "agent_count" => config.agent_count,
        "decision_draws" => config.decision_draws,
        "search_realizations" => config.search_realizations,
        "evaluation_realizations" => config.evaluation_realizations,
        "total_resources" => config.total_resources,
        "allocation_step" => config.allocation_step,
        "premia" => sort!(unique(job.withdrawal_premium for job in jobs)),
        "productivities" => sort!(unique(job.productivity for job in jobs)),
        "withdrawal_probabilities" =>
            sort!(unique(job.withdrawal_probability for job in jobs)),
        "rhos" => sort!(unique(job.rho for job in jobs)),
        "utility_shifts" => sort!(unique(job.utility_shift for job in jobs)),
        "seed_matching" => "common across premium and utility shift",
        "failure_definition" => "any contractual early-payment shortfall",
    )
end

function design_bytes(record)
    io = IOBuffer()
    TOML.print(io, record; sorted=true)
    return take!(io)
end

function initialize_panel(run_dir, panel, jobs, config, chunk_size)
    panel_dir = joinpath(run_dir, panel)
    chunk_dir = joinpath(panel_dir, "chunks")
    mkpath(chunk_dir)
    design_path = joinpath(panel_dir, "design.toml")
    bytes = design_bytes(design_record(panel, jobs, config, chunk_size))
    digest = bytes2hex(sha256(bytes))
    if isfile(design_path)
        existing = read(design_path)
        existing == bytes ||
            error("existing design does not match requested panel: $panel")
    else
        temporary = design_path * ".tmp"
        write(temporary, bytes)
        mv(temporary, design_path)
    end
    fingerprint_path = joinpath(panel_dir, "DESIGN_SHA256")
    if isfile(fingerprint_path)
        strip(read(fingerprint_path, String)) == digest ||
            error("design fingerprint mismatch for panel: $panel")
    else
        write(fingerprint_path, digest * "\n")
    end
    return panel_dir, chunk_dir
end

function completed_indices(chunk_dir)
    completed = Set{Int}()
    for path in sort(filter(endswith(".csv"), readdir(chunk_dir; join=true)))
        frame = CSV.read(path, DataFrame; select=[:job_index])
        union!(completed, Int.(frame.job_index))
    end
    return completed
end

function write_chunk(chunk_dir, panel, results)
    frame = DataFrame(results)
    frame.panel = fill(panel, nrow(frame))
    frame.julia_version = fill(string(VERSION), nrow(frame))
    frame.seed_design =
        fill("common_across_premia_and_utility_shifts", nrow(frame))
    first_index = minimum(frame.job_index)
    last_index = maximum(frame.job_index)
    path = joinpath(
        chunk_dir,
        "chunk_$(lpad(first_index, 6, '0'))_$(lpad(last_index, 6, '0')).csv",
    )
    temporary = path * ".tmp"
    CSV.write(temporary, frame)
    mv(temporary, path)
    return path
end

function merge_panel(panel_dir)
    paths = sort(filter(endswith(".csv"), readdir(
        joinpath(panel_dir, "chunks");
        join=true,
    )))
    frames = CSV.read.(paths, Ref(DataFrame))
    frame = reduce(vcat, frames; cols=:union)
    sort!(frame, :job_index)
    length(unique(frame.job_index)) == nrow(frame) ||
        error("duplicate job indices while merging $(basename(panel_dir))")
    destination = joinpath(panel_dir, "results.csv")
    temporary = destination * ".tmp"
    CSV.write(temporary, frame)
    mv(temporary, destination)
    return destination, nrow(frame)
end

function run_panel(run_dir, panel)
    jobs, config, chunk_size = panel_design(panel)
    panel_dir, chunk_dir =
        initialize_panel(run_dir, panel, jobs, config, chunk_size)
    completed = completed_indices(chunk_dir)
    pending = [job for job in jobs if job.job_index ∉ completed]
    println("$panel: $(length(completed)) complete, $(length(pending)) pending")

    for offset in 1:chunk_size:length(pending)
        batch = pending[offset:min(offset + chunk_size - 1, end)]
        results = if panel == "fixed_sensitivity"
            pmap(job -> run_dd_fixed_job(job, 1_000), batch; batch_size=1)
        else
            pmap(run_dd_job, batch; batch_size=1)
        end
        path = write_chunk(chunk_dir, panel, results)
        println("$panel: wrote $(basename(path))")
        flush(stdout)
    end

    destination, rows = merge_panel(panel_dir)
    rows == length(jobs) ||
        error("$panel merge has $rows rows; expected $(length(jobs))")
    write(joinpath(panel_dir, "COMPLETE"), "rows=$rows\n")
    println("$panel: complete at $destination")
end

function main(args)
    run_dir = isempty(args) ?
        joinpath(dirname(@__DIR__), "runs", "dd_overnight_20260724") :
        abspath(args[1])
    design_only = length(args) >= 2 && args[2] == "--design-only"
    if design_only
        for panel in ("allocation_main", "allocation_shift", "fixed_sensitivity")
            jobs, config, chunk_size = panel_design(panel)
            initialize_panel(run_dir, panel, jobs, config, chunk_size)
            println("$panel: $(length(jobs)) jobs, chunk size $chunk_size")
        end
        return
    end
    target_processes = min(Sys.CPU_THREADS, 16)
    if nprocs() < target_processes
        addprocs(
            target_processes - nprocs();
            exeflags="--project=$(Base.active_project())",
        )
    end
    for worker in workers()
        remotecall_wait(Core.eval, worker, Main, :(using BankRunsFinal))
    end

    mkpath(run_dir)
    for panel in ("allocation_main", "allocation_shift", "fixed_sensitivity")
        run_panel(run_dir, panel)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
