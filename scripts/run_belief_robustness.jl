using Distributed
using BankRunsFinal
using CSV
using DataFrames
using Graphs
using Random

const BELIEF_LAWS = (
    "point_estimate" => PointEstimateBelief(),
    "truncated_geometric" => TruncatedGeometricBelief(),
)

function robustness_jobs(run_seed::RunSeed)
    jobs = NamedTuple[]
    job_index = 0
    for reserve_ratio in (0.20, 0.30, 0.40),
        initial_count in (1, 3),
        replication in 1:100

        job_index += 1
        scenario_seed = derive_seed(
            run_seed,
            7,
            round(Int, 100reserve_ratio),
            initial_count,
            replication,
        )
        rng = Xoshiro(scenario_seed)
        graph = watts_strogatz(200, 10, 0.10; rng)
        initial_withdrawals = randperm(rng, 200)[1:initial_count]
        model_seed = RunSeed(derive_seed(run_seed, 8, job_index))
        for (belief_name, belief) in BELIEF_LAWS
            scenario = NetworkScenario(
                graph,
                fill(10.0, 200),
                reserve_ratio,
                NoDepositInsurance(),
                initial_withdrawals,
                0.1,
                200,
                belief,
            )
            for model in (
                ComparativeNetworkModel(scenario),
                ThresholdNetworkModel(scenario, 0.80),
                ExplicitUtilityNetworkModel(scenario, 1.0, 1.25),
            )
                push!(
                    jobs,
                    (
                        job_index=job_index,
                        scenario_seed=scenario_seed,
                        reserve_ratio=reserve_ratio,
                        initial_count=initial_count,
                        replication=replication,
                        belief=belief_name,
                        model_seed=model_seed,
                        model=LargeSparseNetworkModel(model),
                    ),
                )
            end
        end
    end
    return jobs
end

function main()
    run_seed = RunSeed(isempty(ARGS) ? 20260812 : parse(UInt64, ARGS[1]))
    destination = length(ARGS) >= 2 ?
        abspath(ARGS[2]) :
        joinpath(dirname(@__DIR__), "output", "belief_robustness.csv")

    target_processes = min(Sys.CPU_THREADS, 16)
    if nprocs() < target_processes
        addprocs(
            target_processes - nprocs();
            exeflags="--project=$(Base.active_project())",
        )
    end
    Distributed.remotecall_eval(Main, workers(), :(using BankRunsFinal))

    jobs = robustness_jobs(run_seed)
    model_results = pmap(
        job -> run_network_model(job.model, job.model_seed),
        jobs;
        batch_size=1,
    )
    rows = [
        (
            job_index=job.job_index,
            scenario_seed=job.scenario_seed,
            reserve_ratio=job.reserve_ratio,
            initial_count=job.initial_count,
            replication=job.replication,
            belief=job.belief,
            model=result.model_name,
            run_seed=result.run_seed,
            failed=result.failed,
            initial_withdrawals=result.initial_withdrawals,
            endogenous_withdrawals=result.endogenous_withdrawals,
            total_withdrawals=result.total_withdrawals,
            final_vault=result.final_vault,
            rounds=result.rounds,
        )
        for (job, result) in zip(jobs, model_results)
    ]
    frame = DataFrame(rows)
    sort!(frame, [:job_index, :belief, :model])
    mkpath(dirname(destination))
    CSV.write(destination, frame)
    println("Wrote $(nrow(frame)) belief-robustness results to $destination")
end

main()
