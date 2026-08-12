abstract type ExperimentStage end

struct ConvergenceStage <: ExperimentStage
    draw_counts::Vector{Int}
    replications::Int
end

struct CoverageStage <: ExperimentStage
    decision_draws::Int
    replications::Int
end

struct AdaptiveStage <: ExperimentStage
    decision_draws::Int
    additional_run_budget::Int
    batch_index::Int
end

struct ConfirmatoryStage <: ExperimentStage
    decision_draws::Int
    replications::Int
end

struct MonotonicityStage <: ExperimentStage
    decision_draws::Int
    replications::Int
end

abstract type DecisionSpecification end
struct ComparativeDecisionSpecification <: DecisionSpecification end

struct ThresholdDecisionSpecification <: DecisionSpecification
    threshold::Float64
end

struct ExplicitUtilityDecisionSpecification <: DecisionSpecification
    rho::Float64
    gross_return::Float64
end

abstract type ShockLocationSpecification end
struct RandomShockLocation <: ShockLocationSpecification end
struct LocalizedShockLocation <: ShockLocationSpecification end

struct MonotonicityStructure
    structure_id::Int
    label::String
    deposit_specification::DepositSpecification
    topology_specification::TopologySpecification
    shock_location::ShockLocationSpecification
end

struct MonotonicitySetting
    setting_id::Int
    path::String
    level::Float64
    reserve_ratio::Float64
    insurance_specification::InsuranceSpecification
    shock_size::Int
end

struct NetworkExperimentConfig
    run_seed::RunSeed
    run_directory::String
    agent_count::Int
    reserve_ratios::Vector{Float64}
    shock_sizes::Vector{Int}
    baseline_withdrawal_probability::Float64
    decision_draws::Int
end

struct NetworkExperimentJob
    job_id::String
    stage::String
    structural_index::Int
    replication::Int
    decision_draws::Int
    deposit_specification::DepositSpecification
    topology_specification::TopologySpecification
    insurance_specification::InsuranceSpecification
    reserve_ratio::Float64
    shock_size::Int
    shock_location::ShockLocationSpecification
    decision_specification::DecisionSpecification
    scenario_seed::UInt64
    model_seed::UInt64
    agent_count::Int
    baseline_withdrawal_probability::Float64
end

stage_name(::ConvergenceStage) = "convergence"
stage_name(::CoverageStage) = "coverage"
stage_name(stage::AdaptiveStage) =
    "adaptive/batch_" * lpad(string(stage.batch_index), 4, '0')
stage_name(::ConfirmatoryStage) = "confirmatory"
stage_name(::MonotonicityStage) = "monotonicity"

stage_code(::ConvergenceStage) = 1
stage_code(::CoverageStage) = 2
stage_code(::AdaptiveStage) = 3
stage_code(::ConfirmatoryStage) = 4
stage_code(::MonotonicityStage) = 5

decision_code(::ComparativeDecisionSpecification) = 1
decision_code(::ThresholdDecisionSpecification) = 2
decision_code(::ExplicitUtilityDecisionSpecification) = 3

decision_name(::ComparativeDecisionSpecification) = "comparative"
decision_name(::ThresholdDecisionSpecification) = "threshold"
decision_name(::ExplicitUtilityDecisionSpecification) = "explicit_utility"

shock_code(::RandomShockLocation) = 1
shock_code(::LocalizedShockLocation) = 2
shock_name(::RandomShockLocation) = "random"
shock_name(::LocalizedShockLocation) = "localized"

deposit_name(::HomogeneousDeposits) = "homogeneous"
deposit_name(::ClippedLogNormalDeposits) = "clipped_lognormal"
deposit_name(::ClippedParetoDeposits) = "clipped_pareto"

deposit_parameters(specification::HomogeneousDeposits) =
    "value=$(specification.value)"
deposit_parameters(specification::ClippedLogNormalDeposits) =
    "mu=$(specification.mu);sigma=$(specification.sigma);" *
    "lower=$(specification.lower);upper=$(specification.upper)"
deposit_parameters(specification::ClippedParetoDeposits) =
    "scale=$(specification.scale);alpha=$(specification.alpha);" *
    "lower=$(specification.lower);upper=$(specification.upper)"

topology_name(::WattsStrogatzTopology) = "watts_strogatz"
topology_name(::ErdosRenyiTopology) = "erdos_renyi"
topology_name(::BarabasiAlbertTopology) = "barabasi_albert"
topology_name(::CompleteTopology) = "complete"

topology_parameters(specification::WattsStrogatzTopology) =
    "degree=$(specification.degree);" *
    "rewiring=$(specification.rewiring_probability)"
topology_parameters(specification::ErdosRenyiTopology) =
    "mean_degree=$(specification.mean_degree)"
topology_parameters(specification::BarabasiAlbertTopology) =
    "attachments=$(specification.attachments)"
topology_parameters(::CompleteTopology) = ""

insurance_name(::NoInsuranceSpecification) = "none"
insurance_name(::FixedInsuranceSpecification) = "fixed"
insurance_name(::QuantileInsuranceSpecification) = "quantile"
insurance_name(::AdaptiveInsuranceSpecification) = "adaptive"

insurance_parameters(::NoInsuranceSpecification) = ""
insurance_parameters(specification::FixedInsuranceSpecification) =
    "maximum_payment=$(specification.maximum_payment)"
insurance_parameters(specification::QuantileInsuranceSpecification) =
    "quantile=$(specification.quantile)"
insurance_parameters(::AdaptiveInsuranceSpecification) = ""

function make_experiment_job(
    config::NetworkExperimentConfig,
    stage::ExperimentStage,
    structural_index::Integer,
    replication::Integer,
    decision_draws::Integer,
    deposit_specification::DepositSpecification,
    topology_specification::TopologySpecification,
    insurance_specification::InsuranceSpecification,
    reserve_ratio::Real,
    shock_size::Integer,
    shock_location::ShockLocationSpecification,
    decision_specification::DecisionSpecification,
)
    structure = Int(structural_index)
    replicate = Int(replication)
    draws = Int(decision_draws)
    scenario_seed = derive_seed(
        config.run_seed,
        10,
        stage_code(stage),
        structure,
        replicate,
    )
    # The model seed excludes the decision specification so matched economic
    # models consume a common stream.
    model_seed = derive_seed(
        config.run_seed,
        11,
        stage_code(stage),
        structure,
        replicate,
    )
    identifier_seed = derive_seed(
        config.run_seed,
        12,
        stage_code(stage),
        structure,
        replicate,
        draws,
        decision_code(decision_specification),
    )
    identifier = string(
        replace(stage_name(stage), "/" => "_"),
        "_",
        string(identifier_seed; base=16, pad=16),
    )
    return NetworkExperimentJob(
        identifier,
        stage_name(stage),
        structure,
        replicate,
        draws,
        deposit_specification,
        topology_specification,
        insurance_specification,
        Float64(reserve_ratio),
        Int(shock_size),
        shock_location,
        decision_specification,
        scenario_seed,
        model_seed,
        config.agent_count,
        config.baseline_withdrawal_probability,
    )
end

function make_monotonicity_job(
    config::NetworkExperimentConfig,
    stage::MonotonicityStage,
    structure::MonotonicityStructure,
    setting::MonotonicitySetting,
    replication::Integer,
    decision_specification::DecisionSpecification,
)
    replicate = Int(replication)
    structural_index =
        (structure.structure_id - 1) * length(monotonicity_settings()) +
        setting.setting_id
    scenario_seed = derive_seed(
        config.run_seed,
        10,
        stage_code(stage),
        structure.structure_id,
        replicate,
    )
    model_seed = derive_seed(
        config.run_seed,
        11,
        stage_code(stage),
        structure.structure_id,
        replicate,
    )
    identifier_seed = derive_seed(
        config.run_seed,
        12,
        stage_code(stage),
        structure.structure_id,
        setting.setting_id,
        replicate,
        stage.decision_draws,
        decision_code(decision_specification),
    )
    identifier = string(
        stage_name(stage),
        "_",
        string(identifier_seed; base=16, pad=16),
    )
    return NetworkExperimentJob(
        identifier,
        stage_name(stage),
        structural_index,
        replicate,
        stage.decision_draws,
        structure.deposit_specification,
        structure.topology_specification,
        setting.insurance_specification,
        setting.reserve_ratio,
        setting.shock_size,
        structure.shock_location,
        decision_specification,
        scenario_seed,
        model_seed,
        config.agent_count,
        config.baseline_withdrawal_probability,
    )
end

function economic_model(
    specification::ComparativeDecisionSpecification,
    scenario::NetworkScenario,
)
    return ComparativeNetworkModel(scenario)
end

function economic_model(
    specification::ThresholdDecisionSpecification,
    scenario::NetworkScenario,
)
    return ThresholdNetworkModel(scenario, specification.threshold)
end

function economic_model(
    specification::ExplicitUtilityDecisionSpecification,
    scenario::NetworkScenario,
)
    return ExplicitUtilityNetworkModel(
        scenario,
        specification.rho,
        specification.gross_return,
    )
end

function select_initial_withdrawals(
    rng::AbstractRNG,
    graph::AbstractGraph,
    shock_size::Integer,
    ::RandomShockLocation,
)
    return sparse_sample_ranks(rng, nv(graph), Int(shock_size))
end

function select_initial_withdrawals(
    rng::AbstractRNG,
    graph::AbstractGraph,
    shock_size::Integer,
    ::LocalizedShockLocation,
)
    target = min(Int(shock_size), nv(graph))
    center = rand(rng, 1:nv(graph))
    selected = Int[center]
    seen = BitSet(selected)
    cursor = 1
    while length(selected) < target && cursor <= length(selected)
        neighbors = collect(all_neighbors(graph, selected[cursor]))
        shuffle!(rng, neighbors)
        for neighbor in neighbors
            if !(neighbor in seen)
                push!(seen, neighbor)
                push!(selected, neighbor)
                length(selected) == target && break
            end
        end
        cursor += 1
    end
    if length(selected) < target
        remaining = [index for index in 1:nv(graph) if !(index in seen)]
        shuffle!(rng, remaining)
        append!(selected, remaining[1:(target - length(selected))])
    end
    return selected
end

function run_experiment_job(job::NetworkExperimentJob)
    rng = Xoshiro(job.scenario_seed)
    deposits = generate_deposits(
        rng,
        job.deposit_specification,
        job.agent_count,
    )
    graph = generate_graph(rng, job.topology_specification, job.agent_count)
    insurance = resolve_insurance(job.insurance_specification, deposits)
    initial_withdrawals = select_initial_withdrawals(
        rng,
        graph,
        job.shock_size,
        job.shock_location,
    )
    scenario = NetworkScenario(
        graph,
        deposits,
        job.reserve_ratio,
        insurance,
        initial_withdrawals,
        job.baseline_withdrawal_probability,
        job.decision_draws,
    )
    model = LargeSparseNetworkModel(
        economic_model(job.decision_specification, scenario),
    )
    elapsed = @elapsed result =
        run_network_model(model, RunSeed(job.model_seed))
    return (
        job_id=job.job_id,
        stage=job.stage,
        structural_index=job.structural_index,
        replication=job.replication,
        decision_draws=job.decision_draws,
        deposit_model=deposit_name(job.deposit_specification),
        deposit_parameters=deposit_parameters(job.deposit_specification),
        topology_model=topology_name(job.topology_specification),
        topology_parameters=topology_parameters(job.topology_specification),
        insurance_model=insurance_name(job.insurance_specification),
        insurance_parameters=insurance_parameters(job.insurance_specification),
        reserve_ratio=job.reserve_ratio,
        shock_size=job.shock_size,
        shock_location=shock_name(job.shock_location),
        decision_model=decision_name(job.decision_specification),
        scenario_seed=job.scenario_seed,
        model_seed=job.model_seed,
        failed=result.failed,
        initial_withdrawals=result.initial_withdrawals,
        endogenous_withdrawals=result.endogenous_withdrawals,
        total_withdrawals=result.total_withdrawals,
        final_vault=result.final_vault,
        rounds=result.rounds,
        elapsed_seconds=elapsed,
        above_par_payments=0,
        julia_version=string(VERSION),
        execution_model="large_sparse",
    )
end

function decision_specifications()
    return DecisionSpecification[
        ComparativeDecisionSpecification(),
        ThresholdDecisionSpecification(0.80),
        ExplicitUtilityDecisionSpecification(1.0, 1.25),
    ]
end

shock_location_specifications() =
    ShockLocationSpecification[RandomShockLocation(), LocalizedShockLocation()]

function monotonicity_structures()
    deposits = heuristic_deposit_specifications()
    topologies = heuristic_topology_specifications()
    return MonotonicityStructure[
        MonotonicityStructure(
            1,
            "homogeneous_small_world",
            deposits[1],
            topologies[2],
            RandomShockLocation(),
        ),
        MonotonicityStructure(
            2,
            "homogeneous_complete",
            deposits[1],
            topologies[16],
            LocalizedShockLocation(),
        ),
        MonotonicityStructure(
            3,
            "moderate_lognormal_random",
            deposits[2],
            topologies[10],
            RandomShockLocation(),
        ),
        MonotonicityStructure(
            4,
            "heavy_lognormal_clustered",
            deposits[4],
            topologies[4],
            LocalizedShockLocation(),
        ),
        MonotonicityStructure(
            5,
            "moderate_pareto_scale_free",
            deposits[6],
            topologies[14],
            RandomShockLocation(),
        ),
        MonotonicityStructure(
            6,
            "heavy_pareto_scale_free",
            deposits[5],
            topologies[15],
            LocalizedShockLocation(),
        ),
    ]
end

function monotonicity_settings()
    return MonotonicitySetting[
        MonotonicitySetting(
            1,
            "baseline",
            0.0,
            0.30,
            FixedInsuranceSpecification(5.0),
            5,
        ),
        MonotonicitySetting(
            2,
            "reserve_ratio",
            0.10,
            0.10,
            FixedInsuranceSpecification(5.0),
            5,
        ),
        MonotonicitySetting(
            3,
            "reserve_ratio",
            0.20,
            0.20,
            FixedInsuranceSpecification(5.0),
            5,
        ),
        MonotonicitySetting(
            4,
            "reserve_ratio",
            0.40,
            0.40,
            FixedInsuranceSpecification(5.0),
            5,
        ),
        MonotonicitySetting(
            5,
            "reserve_ratio",
            0.50,
            0.50,
            FixedInsuranceSpecification(5.0),
            5,
        ),
        MonotonicitySetting(
            6,
            "fixed_insurance",
            0.0,
            0.30,
            FixedInsuranceSpecification(0.0),
            5,
        ),
        MonotonicitySetting(
            7,
            "fixed_insurance",
            2.5,
            0.30,
            FixedInsuranceSpecification(2.5),
            5,
        ),
        MonotonicitySetting(
            8,
            "fixed_insurance",
            10.0,
            0.30,
            FixedInsuranceSpecification(10.0),
            5,
        ),
        MonotonicitySetting(
            9,
            "shock_size",
            1.0,
            0.30,
            FixedInsuranceSpecification(5.0),
            1,
        ),
        MonotonicitySetting(
            10,
            "shock_size",
            10.0,
            0.30,
            FixedInsuranceSpecification(5.0),
            10,
        ),
        MonotonicitySetting(
            11,
            "shock_size",
            20.0,
            0.30,
            FixedInsuranceSpecification(5.0),
            20,
        ),
    ]
end

function monotonicity_design_rows()
    rows = NamedTuple[]
    settings = monotonicity_settings()
    for structure in monotonicity_structures(), setting in settings
        push!(
            rows,
            (
                structure_id=structure.structure_id,
                structure_label=structure.label,
                setting_id=setting.setting_id,
                structural_index=
                    (structure.structure_id - 1) * length(settings) +
                    setting.setting_id,
                path=setting.path,
                level=setting.level,
                deposit_model=deposit_name(structure.deposit_specification),
                deposit_parameters=
                    deposit_parameters(structure.deposit_specification),
                topology_model=topology_name(structure.topology_specification),
                topology_parameters=begin
                    parameters =
                        topology_parameters(structure.topology_specification)
                    isempty(parameters) ? "none" : parameters
                end,
                shock_location=shock_name(structure.shock_location),
                reserve_ratio=setting.reserve_ratio,
                insurance_model=
                    insurance_name(setting.insurance_specification),
                insurance_parameters=
                    insurance_parameters(setting.insurance_specification),
                shock_size=setting.shock_size,
            ),
        )
    end
    return rows
end

function monotonicity_hypothesis_rows()
    return [
        (
            path="reserve_ratio",
            outcome="failure",
            expected_direction="nonincreasing",
            ordered_levels="0.10;0.20;0.30;0.40;0.50",
        ),
        (
            path="fixed_insurance",
            outcome="failure",
            expected_direction="nonincreasing",
            ordered_levels="0.0;2.5;5.0;10.0",
        ),
        (
            path="shock_size",
            outcome="failure",
            expected_direction="nondecreasing",
            ordered_levels="1;5;10;20",
        ),
    ]
end

function experiment_jobs(
    config::NetworkExperimentConfig,
    stage::CoverageStage,
)
    jobs = NetworkExperimentJob[]
    structural_index = 0
    for deposit in heuristic_deposit_specifications(),
        topology in heuristic_topology_specifications(),
        insurance in heuristic_insurance_specifications(),
        reserve in config.reserve_ratios,
        shock_size in config.shock_sizes,
        shock_location in shock_location_specifications()
        structural_index += 1
        for replication in 1:stage.replications,
            decision in decision_specifications()
            push!(
                jobs,
                make_experiment_job(
                    config,
                    stage,
                    structural_index,
                    replication,
                    stage.decision_draws,
                    deposit,
                    topology,
                    insurance,
                    reserve,
                    shock_size,
                    shock_location,
                    decision,
                ),
            )
        end
    end
    return jobs
end

function structural_job_templates(
    config::NetworkExperimentConfig,
    decision_draws::Integer,
)
    coverage = CoverageStage(Int(decision_draws), 1)
    jobs = experiment_jobs(config, coverage)
    return Dict(
        job.structural_index => job
        for job in jobs
        if job.decision_specification isa ComparativeDecisionSpecification
    )
end

function experiment_jobs(
    config::NetworkExperimentConfig,
    stage::Union{AdaptiveStage,ConfirmatoryStage},
    selected_structural_indices::AbstractVector{<:Integer},
)
    selected = unique(Int.(selected_structural_indices))
    isempty(selected) && return NetworkExperimentJob[]
    templates = structural_job_templates(config, stage.decision_draws)
    replications = stage isa AdaptiveStage ?
        max(1, stage.additional_run_budget ÷ (3length(selected))) :
        stage.replications
    jobs = NetworkExperimentJob[]
    for structural_index in selected
        haskey(templates, structural_index) ||
            throw(ArgumentError("unknown structural index $structural_index"))
        template = templates[structural_index]
        for replication in 1:replications,
            decision in decision_specifications()
            push!(
                jobs,
                make_experiment_job(
                    config,
                    stage,
                    structural_index,
                    replication,
                    stage.decision_draws,
                    template.deposit_specification,
                    template.topology_specification,
                    template.insurance_specification,
                    template.reserve_ratio,
                    template.shock_size,
                    template.shock_location,
                    decision,
                ),
            )
        end
    end
    stage isa AdaptiveStage &&
        resize!(jobs, min(length(jobs), stage.additional_run_budget))
    return jobs
end

function experiment_jobs(
    config::NetworkExperimentConfig,
    stage::ConvergenceStage,
)
    deposits = heuristic_deposit_specifications()
    topologies = heuristic_topology_specifications()
    insurances = heuristic_insurance_specifications()
    jobs = NetworkExperimentJob[]
    structural_index = 0
    for design_index in 1:24,
        shock_location in shock_location_specifications()
        structural_index += 1
        deposit = deposits[mod1(design_index, length(deposits))]
        topology = topologies[mod1(3design_index, length(topologies))]
        insurance = insurances[mod1(5design_index, length(insurances))]
        reserve = config.reserve_ratios[mod1(design_index, length(config.reserve_ratios))]
        shock_size = config.shock_sizes[mod1(design_index, length(config.shock_sizes))]
        for draws in stage.draw_counts,
            replication in 1:stage.replications,
            decision in decision_specifications()
            push!(
                jobs,
                make_experiment_job(
                    config,
                    stage,
                    structural_index,
                    replication,
                    draws,
                    deposit,
                    topology,
                    insurance,
                    reserve,
                    shock_size,
                    shock_location,
                    decision,
                ),
            )
        end
    end
    return jobs
end

function experiment_jobs(
    config::NetworkExperimentConfig,
    stage::MonotonicityStage,
)
    stage.replications > 0 ||
        throw(ArgumentError("replications must be positive"))
    jobs = NetworkExperimentJob[]
    for structure in monotonicity_structures(),
        setting in monotonicity_settings(),
        replication in 1:stage.replications,
        decision in decision_specifications()
        push!(
            jobs,
            make_monotonicity_job(
                config,
                stage,
                structure,
                setting,
                replication,
                decision,
            ),
        )
    end
    return jobs
end
