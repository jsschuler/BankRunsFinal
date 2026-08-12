using Distributed
using BankRunsFinal
using CSV
using DataFrames

function parse_run_seed(args)
    isempty(args) && return RunSeed(20260724)
    return RunSeed(parse(UInt64, args[1]))
end

function output_path(args)
    length(args) >= 2 && return abspath(args[2])
    return joinpath(dirname(@__DIR__), "output", "dd_fixed_small_epsilon.csv")
end

run_seed = parse_run_seed(ARGS)
destination = output_path(ARGS)

target_processes = min(Sys.CPU_THREADS, 16)
if nprocs() < target_processes
    addprocs(
        target_processes - nprocs();
        exeflags="--project=$(Base.active_project())",
    )
end
@everywhere using BankRunsFinal

config = DDConfig(
    agent_count=50,
    decision_draws=100,
    search_realizations=1,
    evaluation_realizations=10_000,
    total_resources=1_000,
    allocation_step=10,
)
jobs = dd_jobs(
    run_seed;
    withdrawal_premia=(0.0, 0.01, 0.02, 0.05, 0.10),
    config,
)
results = pmap(job -> run_dd_fixed_job(job, 1_000), jobs; batch_size=1)
sort!(results; by=result -> result.job_index)

mkpath(dirname(destination))
frame = DataFrame(results)
frame.julia_version = fill(string(VERSION), nrow(frame))
frame.decision_draws = fill(config.decision_draws, nrow(frame))
frame.seed_design = fill("common_across_withdrawal_premia", nrow(frame))
frame.evaluation_design = fill("fixed_full_deposit_independent_holdout", nrow(frame))
CSV.write(destination, frame)

println("Wrote $(nrow(frame)) fixed-allocation DD results to $destination")
