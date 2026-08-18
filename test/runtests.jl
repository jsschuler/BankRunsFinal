using BankRunsFinal
using DataFrames
using Distributions
using Graphs
using Random
using Statistics
using Test

include(joinpath(@__DIR__, "..", "scripts", "network_experiment.jl"))

@testset "stable seed derivation" begin
    run_seed = RunSeed(20260723)
    @test derive_seed(run_seed, 1, 2, 3) == derive_seed(run_seed, 1, 2, 3)
    @test derive_seed(run_seed, 1, 2, 3) != derive_seed(run_seed, 1, 2, 4)
end

@testset "conditioned Binomial sampler" begin
    rng = Xoshiro(91234)
    samples = sample_conditioned_binomial(rng, 50, 0.2, 8, 20_000)

    @test all(8 .<= samples .<= 50)

    # Exact conditional mean computed from the finite Binomial support.
    weights = [
        binomial(50, count) * 0.2^count * 0.8^(50 - count)
        for count in 8:50
    ]
    expected_mean = sum((8:50) .* weights) / sum(weights)
    @test isapprox(sum(samples) / length(samples), expected_mean; atol=0.08)

    @test all(sample_conditioned_binomial(Xoshiro(1), 10, 0.0, 0, 20) .== 0)
    @test all(sample_conditioned_binomial(Xoshiro(1), 10, 1.0, 4, 20) .== 10)
    @test all(sample_conditioned_binomial(Xoshiro(1), 10, 0.3, 10, 20) .== 10)
    @test all(sample_conditioned_binomial(Xoshiro(1), 50, 0.05, 23, 20) .>= 23)
    @test_throws ArgumentError sample_conditioned_binomial(
        Xoshiro(1),
        10,
        0.0,
        1,
        1,
    )
end

@testset "default DD grid excludes zero withdrawal probability" begin
    jobs = dd_jobs(RunSeed(1))
    @test length(jobs) == 360
    @test minimum(job.withdrawal_probability for job in jobs) == 0.05
end

@testset "DD preference grid and allocation search" begin
    tiny_config = DDConfig(
        agent_count=6,
        decision_draws=8,
        search_realizations=4,
        evaluation_realizations=6,
        total_resources=20,
        allocation_step=10,
    )
    jobs = dd_jobs(
        RunSeed(44);
        withdrawal_premia=(0.5,),
        productivities=(0.5,),
        withdrawal_probabilities=(0.2,),
        rhos=(1.0, 0.0),
        config=tiny_config,
    )

    @test length(jobs) == 2
    @test [job.rho for job in jobs] == [1.0, 0.0]

    first_result = run_dd_job(jobs[1])
    repeated_result = run_dd_job(jobs[1])
    @test first_result == repeated_result
    @test first_result.search_realizations == 4
    @test first_result.evaluation_realizations == 6
    @test first_result.optimal_deposit in 0:10:20
    @test first_result.bank_formed == (first_result.optimal_deposit > 0)
    @test 0.0 <= first_result.failure_rate <= 1.0
end

@testset "DD shifted CRRA calibration axis" begin
    config = DDConfig(
        agent_count=4,
        decision_draws=4,
        search_realizations=2,
        evaluation_realizations=3,
        total_resources=20,
        allocation_step=10,
    )
    jobs = dd_jobs(
        RunSeed(45);
        withdrawal_premia=(0.1,),
        productivities=(0.5,),
        withdrawal_probabilities=(0.2,),
        rhos=(1.0,),
        utility_shifts=(0.1, 1.0, 10.0),
        config,
    )
    @test length(jobs) == 3
    @test [job.utility_shift for job in jobs] == [0.1, 1.0, 10.0]
    @test BankRunsFinal.shifted_crra(0.0, 1.0, 0.1) == log(0.1)
    @test BankRunsFinal.shifted_crra(0.0, 1.0, 10.0) == log(10.0)
    results = run_dd_fixed_job.(jobs, 20)
    @test length(unique(result.model_seed for result in results)) == 1
end

@testset "DD zero deposit is nonparticipation, not failure" begin
    config = DDConfig(
        agent_count=6,
        decision_draws=8,
        search_realizations=2,
        evaluation_realizations=3,
        total_resources=20,
        allocation_step=10,
    )
    job = DDJob(1, RunSeed(91), 0.5, 0.5, 1.0, 1.0, config)
    realization = BankRunsFinal.realize_model(Xoshiro(92), job, 0)
    @test !realization.failed
    @test realization.mean_utility == BankRunsFinal.shifted_crra(20.0, 1.0)
end

@testset "DD exact exhaustion is settlement, short payment is failure" begin
    config = DDConfig(
        agent_count=4,
        decision_draws=4,
        search_realizations=1,
        evaluation_realizations=3,
        total_resources=20,
        allocation_step=10,
    )

    par_job = DDJob(1, RunSeed(92), 0.0, 0.5, 1.0, 1.0, config)
    par_realization = BankRunsFinal.realize_model(Xoshiro(93), par_job, 20)
    @test !par_realization.failed
    @test par_realization.initial_withdrawal_count == 4
    @test par_realization.executed_initial_withdrawal_count == 4
    @test par_realization.total_withdrawal_count == 4
    @test par_realization.shortfall_count == 0
    @test par_realization.shortfall_amount == 0.0

    premium_job = DDJob(2, RunSeed(92), 0.1, 0.5, 1.0, 1.0, config)
    premium_realization =
        BankRunsFinal.realize_model(Xoshiro(93), premium_job, 20)
    @test premium_realization.failed
    @test premium_realization.total_withdrawal_count == 4
    @test premium_realization.shortfall_count > 0
    @test premium_realization.shortfall_amount > 0.0

    fixed_result = run_dd_fixed_job(par_job, 20)
    @test fixed_result.failure_rate == 0.0
    @test fixed_result.mean_initial_withdrawals == 4.0
    @test fixed_result.mean_total_withdrawals == 4.0
end

@testset "DD common random numbers across premiums" begin
    tiny_config = DDConfig(
        agent_count=4,
        decision_draws=4,
        search_realizations=2,
        evaluation_realizations=3,
        total_resources=10,
        allocation_step=10,
    )
    jobs = dd_jobs(
        RunSeed(55);
        withdrawal_premia=(0.5, 0.6),
        productivities=(0.5,),
        withdrawal_probabilities=(0.2,),
        rhos=(1.0,),
        config=tiny_config,
    )
    results = run_dd_job.(jobs)
    @test results[1].model_seed == results[2].model_seed
end

@testset "partial-payment conventions" begin
    withdraw = RecoveryCounts(6, 3, 1)
    stay = RecoveryCounts(5, 2, 3)

    favor_withdrawal = recovery_probabilities(
        PairedRecoveryCounts(withdraw, stay),
        WithdrawalFavoringBound(),
    )
    favor_staying = recovery_probabilities(
        PairedRecoveryCounts(withdraw, stay),
        StayingFavoringBound(),
    )

    @test favor_withdrawal.p_full_if_withdraw == 0.9
    @test favor_withdrawal.p_full_if_stay == 0.5
    @test favor_staying.p_full_if_withdraw == 0.6
    @test favor_staying.p_full_if_stay == 0.7
end

@testset "withdrawal decision modes" begin
    certain_stay = RecoveryProbabilities(1.0, 1.0)
    @test !should_withdraw(certain_stay, RelativeSafety())
    @test !should_withdraw(certain_stay, BridgeThreshold(0.8))
    @test !should_withdraw(certain_stay, CRRARiskNeutral(1.2))

    probabilities = RecoveryProbabilities(0.8, 0.7)
    @test should_withdraw(probabilities, RelativeSafety())
    @test !should_withdraw(probabilities, BridgeThreshold(0.6))
    @test !should_withdraw(
        probabilities,
        CRRARiskNeutral(1.2),
    )
end

@testset "typed paired partial-payment bounds" begin
    counts = PairedRecoveryCounts(
        RecoveryCounts(6, 3, 1),
        RecoveryCounts(5, 2, 3),
    )
    withdrawal_bound, staying_bound =
        evaluate_bounds(RelativeSafety(), counts)

    @test withdrawal_bound.bound isa WithdrawalFavoringBound
    @test staying_bound.bound isa StayingFavoringBound
    @test withdrawal_bound.withdraw
    @test !staying_bound.withdraw
    @test_throws ArgumentError PairedRecoveryCounts(
        RecoveryCounts(1, 1, 1),
        RecoveryCounts(1, 1, 2),
    )
end

@testset "paired payment classification" begin
    counts = paired_recovery_counts(
        [10.0, 4.0, 0.0, 12.0],
        [0.0, 6.0, 10.0, 3.0],
        fill(10.0, 4),
    )
    @test counts.withdraw == RecoveryCounts(2, 1, 1)
    @test counts.stay == RecoveryCounts(1, 2, 1)
    @test recovery_outcome(0.0, 10.0) isa ZeroRecovery
    @test recovery_outcome(5.0, 10.0) isa PartialRecovery
    @test recovery_outcome(10.0, 10.0) isa FullRecovery
    @test_throws ArgumentError paired_recovery_counts(
        [1.0],
        [1.0, 2.0],
        [2.0],
    )
end

@testset "corrected subjective network state" begin
    state = NetworkState(fill(10.0, 4), 0.625)
    @test BankRunsFinal.withdraw!(state, 1) == 10.0
    snapshot_after_first = subjective_snapshot(state)

    # A later endogenous withdrawal must appear in every newly created snapshot.
    @test BankRunsFinal.withdraw!(state, 4) == 10.0
    snapshot_after_second = subjective_snapshot(state)
    @test snapshot_after_first.banked[4]
    @test !snapshot_after_second.banked[4]
    @test snapshot_after_second.vault == 5.0

    # Already-withdrawn agents in an anticipated order are skipped, never paid
    # or subtracted from the vault for a second time.
    old_snapshot_payment = simulate_recovery(
        snapshot_after_first,
        2,
        [1, 3],
        StayUntilAfterExpectedWithdrawals(),
    )
    @test old_snapshot_payment == 5.0

    payments = paired_recovery_payments(
        snapshot_after_first,
        2,
        [[1, 3], [3]],
    )
    @test payments.withdraw_payments == [10.0, 10.0]
    @test payments.stay_payments == [5.0, 5.0]
    counts = paired_recovery_counts(
        payments.withdraw_payments,
        payments.stay_payments,
        fill(10.0, 2),
    )
    @test counts.withdraw == RecoveryCounts(2, 0, 0)
    @test counts.stay == RecoveryCounts(0, 2, 0)
    @test_throws ArgumentError BankRunsFinal.withdraw!(state, 1)
end

@testset "distinct finite-agent DD bridge model" begin
    model = FiniteAgentDDBridgeModel(4, 10.0, 0.5, 0.5, 0.25)
    state = initial_bridge_state(model)
    @test !(state isa SubjectiveSnapshot)
    @test !(model isa NetworkState)

    withdraw_payment =
        simulate_recovery(model, state, 2, DDBridgeWithdrawNow())
    stay_payment = simulate_recovery(model, state, 2, DDBridgeStay())
    @test withdraw_payment == 15.0
    @test stay_payment == 10.0

    first = paired_recovery_payments(Xoshiro(99), model, state, 100)
    second = paired_recovery_payments(Xoshiro(99), model, state, 100)
    @test first == second
    @test length(first.future_counts) == 100
    @test length(first.withdraw_payments) == 100
    @test length(first.stay_payments) == 100
end

@testset "typed local-information network models" begin
    graph = cycle_graph(20)
    scenario = NetworkScenario(
        graph,
        fill(10.0, 20),
        0.5,
        NoDepositInsurance(),
        [1],
        0.05,
        100,
    )
    comparative = ComparativeNetworkModel(scenario)
    threshold = ThresholdNetworkModel(scenario, 0.75)
    explicit = ExplicitUtilityNetworkModel(scenario, 1.0, 1.25)

    @test typeof(comparative) != typeof(threshold)
    @test typeof(threshold) != typeof(explicit)

    state = NetworkState(scenario.deposits, scenario.reserve_ratio)
    BankRunsFinal.withdraw!(state, 1)
    @test BankRunsFinal.local_withdrawal_probability(
        comparative,
        state,
        2,
    ) == 0.5
    @test BankRunsFinal.local_withdrawal_probability(
        comparative,
        state,
        10,
    ) == 0.05

    snapshot = subjective_snapshot(state)
    payments = paired_recovery_payments(snapshot, 2, [[3, 4, 5], [1, 3]])
    @test all(payments.withdraw_payments .<= 10.0)
    @test all(payments.stay_payments .<= 10.0)

    for model in (comparative, threshold, explicit)
        first = run_network_model(model, RunSeed(88))
        repeated = run_network_model(model, RunSeed(88))
        @test first == repeated
        @test first.total_withdrawals >= first.initial_withdrawals
    end
end

@testset "alternative belief laws" begin
    graph = cycle_graph(20)
    default_scenario = NetworkScenario(
        graph,
        fill(10.0, 20),
        0.5,
        NoDepositInsurance(),
        [1],
        0.05,
        100,
    )
    # Omitting the belief argument must still select the production
    # default, so every existing call site keeps its exact prior behavior.
    @test default_scenario.belief isa PointEstimateBelief

    geometric_scenario = NetworkScenario(
        graph,
        fill(10.0, 20),
        0.5,
        NoDepositInsurance(),
        [1],
        0.5,
        100,
        TruncatedGeometricBelief(),
    )
    @test geometric_scenario.belief isa TruncatedGeometricBelief

    comparative = ComparativeNetworkModel(default_scenario)
    state = NetworkState(default_scenario.deposits, default_scenario.reserve_ratio)
    BankRunsFinal.withdraw!(state, 1)
    eligible_count = length(state.active_agents) - 1

    # PointEstimateBelief must draw from the exact pre-existing Binomial:
    # same distribution, so a fixed seed reproduces the same draw.
    probability = BankRunsFinal.local_withdrawal_probability(comparative, state, 2)
    @test BankRunsFinal.draw_future_withdrawal_count(
        Xoshiro(7),
        PointEstimateBelief(),
        comparative,
        state,
        2,
        eligible_count,
    ) == rand(Xoshiro(7), Binomial(eligible_count, probability))

    # draw_future_withdrawal_count is a pure function of its rng argument.
    geometric_comparative = ComparativeNetworkModel(geometric_scenario)
    @test BankRunsFinal.draw_future_withdrawal_count(
        Xoshiro(11),
        TruncatedGeometricBelief(),
        geometric_comparative,
        state,
        2,
        eligible_count,
    ) == BankRunsFinal.draw_future_withdrawal_count(
        Xoshiro(11),
        TruncatedGeometricBelief(),
        geometric_comparative,
        state,
        2,
        eligible_count,
    )

    # With no neighbor observations and no prior withdrawals, the locally
    # implied lower bound is zero, so by the Geometric's memorylessness
    # the draw is exactly Geometric(p0): its empirical mean should match
    # (1 - p0) / p0 (using a large eligible_count so clamping is negligible).
    fresh_state = NetworkState(fill(10.0, 20), 0.5)
    p0 = 0.5
    unconditioned_scenario = NetworkScenario(
        cycle_graph(20),
        fill(10.0, 20),
        0.5,
        NoDepositInsurance(),
        Int[],
        p0,
        100,
        TruncatedGeometricBelief(),
    )
    unconditioned_model = ComparativeNetworkModel(unconditioned_scenario)
    rng = Xoshiro(2026)
    draws = [
        BankRunsFinal.draw_future_withdrawal_count(
            rng,
            TruncatedGeometricBelief(),
            unconditioned_model,
            fresh_state,
            1,
            50,
        )
        for _ in 1:20_000
    ]
    @test all(0 .<= draws .<= 50)
    @test isapprox(mean(draws), (1 - p0) / p0; atol=0.1)

    # A high locally observed withdrawal rate scaled up to the full
    # population can imply more eventual withdrawals than currently
    # remain eligible; the belief must clamp rather than overflow.
    saturated_state = NetworkState(fill(10.0, 20), 0.5)
    BankRunsFinal.withdraw!(saturated_state, 2)
    BankRunsFinal.withdraw!(saturated_state, 20)
    saturated_eligible = length(saturated_state.active_agents) - 1
    saturated_draws = [
        BankRunsFinal.draw_future_withdrawal_count(
            rng,
            TruncatedGeometricBelief(),
            geometric_comparative,
            saturated_state,
            1,
            saturated_eligible,
        )
        for _ in 1:100
    ]
    @test all(==(saturated_eligible), saturated_draws)

    geometric_model = ComparativeNetworkModel(geometric_scenario)
    first = run_network_model(geometric_model, RunSeed(88))
    repeated = run_network_model(geometric_model, RunSeed(88))
    @test first == repeated
    @test first.total_withdrawals >= first.initial_withdrawals
end

@testset "small-object and large-sparse execution parity" begin
    graph = cycle_graph(12)
    scenario = NetworkScenario(
        graph,
        collect(5.0:5.0:60.0),
        0.45,
        FixedDepositInsurance(7.5),
        [1, 7],
        0.04,
        50,
    )
    economic_models = (
        ComparativeNetworkModel(scenario),
        ThresholdNetworkModel(scenario, 0.8),
        ExplicitUtilityNetworkModel(scenario, 1.0, 1.25),
    )

    state = NetworkState(
        scenario.deposits,
        scenario.reserve_ratio,
        scenario.insurance,
    )
    BankRunsFinal.withdraw!(state, 1)
    BankRunsFinal.withdraw!(state, 7)
    orders = [[2, 4, 9], [7, 3], Int[], [11, 6, 5, 8]]

    for economic_model in economic_models
        small = SmallObjectNetworkModel(economic_model)
        large = LargeSparseNetworkModel(economic_model)
        small_payments =
            BankRunsFinal.subjective_payments(small, state, 10, orders)
        large_payments =
            BankRunsFinal.subjective_payments(large, state, 10, orders)
        @test small_payments == large_payments
        @test run_network_model(small, RunSeed(909)) ==
              run_network_model(large, RunSeed(909))
        @test all(large_payments.withdraw_payments .<= state.deposits[10])
        @test all(large_payments.stay_payments .<= state.deposits[10])
    end
end

@testset "sparse without-replacement withdrawal sampler" begin
    rng = Xoshiro(404)
    for sample_size in (0, 1, 7, 49, 51, 99, 100)
        sample = sparse_sample_ranks(rng, 100, sample_size)
        @test length(sample) == sample_size
        @test length(unique(sample)) == sample_size
        @test all(1 .<= sample .<= 100)
    end

    state = NetworkState(fill(1.0, 20), 1.0)
    for withdrawn in (3, 11, 18)
        BankRunsFinal.withdraw!(state, withdrawn)
    end
    @test length(state.active_agents) == 17
    @test all(
        state.active_agents[state.active_position[agent]] == agent
        for agent in state.active_agents
    )
    selected = sparse_sample_active_agents(Xoshiro(9), state, 7, 12)
    @test length(unique(selected)) == 12
    @test !(7 in selected)
    @test all(state.banked[selected])

    inclusion_counts = zeros(Int, 20)
    uniform_rng = Xoshiro(818)
    for _ in 1:10_000
        for rank in sparse_sample_ranks(uniform_rng, 20, 4)
            inclusion_counts[rank] += 1
        end
    end
    @test all(abs.(inclusion_counts .- 2_000) .< 150)
end

@testset "typed deposit specifications" begin
    specifications = heuristic_deposit_specifications()
    @test length(specifications) == 7
    for specification in specifications
        first = generate_deposits(Xoshiro(77), specification, 10_000)
        repeated = generate_deposits(Xoshiro(77), specification, 10_000)
        @test first == repeated
        @test length(first) == 10_000
        @test all(first .> 0.0)
        @test isapprox(mean(first), 10.0; atol=0.02)
        if specification isa Union{
            ClippedLogNormalDeposits,
            ClippedParetoDeposits,
        }
            @test minimum(first) >= specification.lower
            @test maximum(first) <= specification.upper
        end
    end
end

@testset "typed topology specifications" begin
    specifications = heuristic_topology_specifications()
    @test length(specifications) == 16
    for specification in specifications
        first = generate_graph(Xoshiro(17), specification, 50)
        repeated = generate_graph(Xoshiro(17), specification, 50)
        @test first == repeated
        @test nv(first) == 50
        @test ne(first) > 0
    end
    complete = generate_graph(Xoshiro(1), CompleteTopology(), 50)
    @test ne(complete) == 1_225
end

@testset "typed insurance specifications" begin
    deposits = [1.0, 2.0, 100.0]
    @test resolve_insurance(
        NoInsuranceSpecification(),
        deposits,
    ) isa NoDepositInsurance
    fixed = resolve_insurance(FixedInsuranceSpecification(8.0), deposits)
    @test fixed == FixedDepositInsurance(8.0)
    quantile_model = resolve_insurance(
        QuantileInsuranceSpecification(0.5),
        deposits,
    )
    @test quantile_model == FixedDepositInsurance(2.0)
    @test resolve_insurance(
        AdaptiveInsuranceSpecification(),
        deposits,
    ) isa AdaptiveDepositInsurance

    adaptive_state =
        NetworkState([5.0, 20.0, 30.0], 0.0, AdaptiveDepositInsurance())
    @test BankRunsFinal.withdraw!(adaptive_state, 1) == 0.0
    @test BankRunsFinal.withdraw!(adaptive_state, 2) == 5.0
    @test BankRunsFinal.withdraw!(adaptive_state, 3) == 20.0

    graph = cycle_graph(8)
    adaptive_scenario = NetworkScenario(
        graph,
        collect(5.0:5.0:40.0),
        0.2,
        AdaptiveDepositInsurance(),
        [1],
        0.05,
        20,
    )
    economic_model = ComparativeNetworkModel(adaptive_scenario)
    @test run_network_model(
        SmallObjectNetworkModel(economic_model),
        RunSeed(606),
    ) == run_network_model(
        LargeSparseNetworkModel(economic_model),
        RunSeed(606),
    )
end

@testset "staged experiment jobs and matched seeds" begin
    config = NetworkExperimentConfig(
        RunSeed(700),
        "/tmp/not-used",
        40,
        [0.20, 0.30, 0.40],
        [1, 10],
        0.02,
        200,
    )
    stage = ConvergenceStage([100, 200], 1)
    jobs = experiment_jobs(config, stage)
    @test length(jobs) == 288
    @test length(unique(job.job_id for job in jobs)) == length(jobs)

    matched = filter(
        job -> job.structural_index == 1 && job.replication == 1,
        jobs,
    )
    @test length(matched) == 6
    @test length(unique(job.scenario_seed for job in matched)) == 1
    @test length(unique(job.model_seed for job in matched)) == 1
    @test length(unique(job.job_id for job in matched)) == 6

    first_result = run_experiment_job(first(matched))
    repeated_result = run_experiment_job(first(matched))
    @test first_result.job_id == repeated_result.job_id
    @test first_result.failed == repeated_result.failed
    @test first_result.total_withdrawals == repeated_result.total_withdrawals

    graph = cycle_graph(40)
    localized = select_initial_withdrawals(
        Xoshiro(80),
        graph,
        10,
        LocalizedShockLocation(),
    )
    random = select_initial_withdrawals(
        Xoshiro(80),
        graph,
        10,
        RandomShockLocation(),
    )
    @test length(unique(localized)) == 10
    @test length(unique(random)) == 10
    @test is_connected(induced_subgraph(graph, localized)[1])

    adaptive_jobs = experiment_jobs(
        config,
        AdaptiveStage(200, 30, 1),
        [1, 2],
    )
    confirmatory_jobs = experiment_jobs(
        config,
        ConfirmatoryStage(200, 4),
        [1, 2],
    )
    @test length(adaptive_jobs) == 30
    @test length(confirmatory_jobs) == 24
    @test all(job.stage == "adaptive/batch_0001" for job in adaptive_jobs)
    @test all(job.stage == "confirmatory" for job in confirmatory_jobs)
end

@testset "prespecified monotonicity jobs and matched paths" begin
    config = NetworkExperimentConfig(
        RunSeed(701),
        "/tmp/not-used",
        40,
        [0.20, 0.30, 0.40],
        [1, 10],
        0.02,
        200,
    )
    stage = MonotonicityStage(200, 2)
    jobs = experiment_jobs(config, stage)
    design = DataFrame(monotonicity_design_rows())
    hypotheses = DataFrame(monotonicity_hypothesis_rows())

    @test length(jobs) == 6 * 11 * 3 * 2
    @test length(unique(job.job_id for job in jobs)) == length(jobs)
    @test nrow(design) == 66
    @test length(unique(design.structure_id)) == 6
    @test all(nrow(group) == 11 for group in groupby(design, :structure_id))
    @test nrow(hypotheses) == 3

    matched = filter(
        job -> job.replication == 1 &&
               job.decision_specification isa
               ComparativeDecisionSpecification,
        jobs,
    )
    for group in Iterators.partition(matched, 11)
        @test length(unique(job.scenario_seed for job in group)) == 1
        @test length(unique(job.model_seed for job in group)) == 1
        @test length(unique(job.job_id for job in group)) == 11
    end
end

@testset "adaptive-result confirmatory selection learning" begin
    rows = NamedTuple[]
    probabilities = Dict(
        1 => [0.50, 0.50, 0.50],
        2 => [0.10, 0.50, 0.90],
        3 => [0.00, 0.00, 0.00],
        4 => [1.00, 1.00, 1.00],
    )
    models = ["comparative", "threshold", "explicit_utility"]
    for structural_index in 1:4, (model_index, model) in pairs(models),
        replication in 1:100
        distinct_design = structural_index >= 3
        push!(
            rows,
            (
                structural_index,
                decision_model=model,
                failed=replication <=
                    round(Int, 100probabilities[structural_index][model_index]),
                elapsed_seconds=1.0,
                deposit_model=distinct_design ? "clipped_pareto" : "homogeneous",
                topology_model=distinct_design ? "complete" : "erdos_renyi",
                insurance_model=distinct_design ? "adaptive" : "none",
                reserve_ratio=distinct_design ? 0.4 : 0.2,
                shock_size=distinct_design ? 10 : 1,
                shock_location=distinct_design ? "localized" : "random",
            ),
        )
    end

    scores = score_adaptive_results(DataFrame(rows))
    @test nrow(scores) == 4
    @test scores.structural_index[1] == 2
    @test all(scores.replications_per_model .== 100)

    selection = diverse_confirmatory_selection(
        scores;
        cell_count=2,
        diversity_weight=10.0,
    )
    @test selection.structural_index[1] == 2
    @test selection.structural_index[2] in (3, 4)
    @test selection.selection_rank == [1, 2]
end
