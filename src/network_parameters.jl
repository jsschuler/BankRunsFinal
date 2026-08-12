abstract type DepositSpecification end

struct HomogeneousDeposits <: DepositSpecification
    value::Float64

    function HomogeneousDeposits(value::Real)
        amount = Float64(value)
        amount > 0.0 || throw(ArgumentError("deposit value must be positive"))
        new(amount)
    end
end

struct ClippedLogNormalDeposits <: DepositSpecification
    mu::Float64
    sigma::Float64
    lower::Float64
    upper::Float64
    target_mean::Float64

    function ClippedLogNormalDeposits(
        mu::Real,
        sigma::Real,
        lower::Real,
        upper::Real,
        target_mean::Real,
    )
        spread = Float64(sigma)
        low = Float64(lower)
        high = Float64(upper)
        target = Float64(target_mean)
        spread > 0.0 || throw(ArgumentError("sigma must be positive"))
        0.0 < low < high || throw(ArgumentError("clipping bounds must satisfy 0 < lower < upper"))
        low <= target <= high ||
            throw(ArgumentError("target_mean must lie inside clipping bounds"))
        new(Float64(mu), spread, low, high, target)
    end
end

struct ClippedParetoDeposits <: DepositSpecification
    scale::Float64
    alpha::Float64
    lower::Float64
    upper::Float64
    target_mean::Float64

    function ClippedParetoDeposits(
        scale::Real,
        alpha::Real,
        lower::Real,
        upper::Real,
        target_mean::Real,
    )
        minimum_value = Float64(scale)
        shape = Float64(alpha)
        low = Float64(lower)
        high = Float64(upper)
        target = Float64(target_mean)
        minimum_value > 0.0 || throw(ArgumentError("scale must be positive"))
        shape > 1.0 || throw(ArgumentError("alpha must exceed one"))
        0.0 < low < high || throw(ArgumentError("clipping bounds must satisfy 0 < lower < upper"))
        low <= target <= high ||
            throw(ArgumentError("target_mean must lie inside clipping bounds"))
        new(minimum_value, shape, low, high, target)
    end
end

generate_deposits(
    rng::AbstractRNG,
    specification::HomogeneousDeposits,
    agent_count::Integer,
) = fill(specification.value, Int(agent_count))

function normalize_clipped!(
    deposits::Vector{Float64},
    target_mean::Float64,
    lower::Float64,
    upper::Float64,
)
    for _ in 1:8
        deposits .*= target_mean / mean(deposits)
        clamp!(deposits, lower, upper)
    end
    return deposits
end

function generate_deposits(
    rng::AbstractRNG,
    specification::ClippedLogNormalDeposits,
    agent_count::Integer,
)
    deposits = clamp.(
        rand(
            rng,
            LogNormal(specification.mu, specification.sigma),
            Int(agent_count),
        ),
        specification.lower,
        specification.upper,
    )
    return normalize_clipped!(
        deposits,
        specification.target_mean,
        specification.lower,
        specification.upper,
    )
end

function generate_deposits(
    rng::AbstractRNG,
    specification::ClippedParetoDeposits,
    agent_count::Integer,
)
    deposits = clamp.(
        rand(
            rng,
            Pareto(specification.alpha, specification.scale),
            Int(agent_count),
        ),
        specification.lower,
        specification.upper,
    )
    return normalize_clipped!(
        deposits,
        specification.target_mean,
        specification.lower,
        specification.upper,
    )
end

abstract type TopologySpecification end

struct WattsStrogatzTopology <: TopologySpecification
    degree::Int
    rewiring_probability::Float64

    function WattsStrogatzTopology(degree::Integer, probability::Real)
        neighbors = Int(degree)
        rewiring = Float64(probability)
        neighbors > 0 && iseven(neighbors) ||
            throw(ArgumentError("degree must be a positive even integer"))
        0.0 <= rewiring <= 1.0 ||
            throw(ArgumentError("rewiring probability must be in [0, 1]"))
        new(neighbors, rewiring)
    end
end

struct ErdosRenyiTopology <: TopologySpecification
    mean_degree::Float64

    function ErdosRenyiTopology(mean_degree::Real)
        degree = Float64(mean_degree)
        degree > 0.0 || throw(ArgumentError("mean_degree must be positive"))
        new(degree)
    end
end

struct BarabasiAlbertTopology <: TopologySpecification
    attachments::Int

    function BarabasiAlbertTopology(attachments::Integer)
        count = Int(attachments)
        count > 0 || throw(ArgumentError("attachments must be positive"))
        new(count)
    end
end

struct CompleteTopology <: TopologySpecification end

function generate_graph(
    rng::AbstractRNG,
    specification::WattsStrogatzTopology,
    agent_count::Integer,
)
    return watts_strogatz(
        Int(agent_count),
        specification.degree,
        specification.rewiring_probability;
        rng,
    )
end

function generate_graph(
    rng::AbstractRNG,
    specification::ErdosRenyiTopology,
    agent_count::Integer,
)
    count = Int(agent_count)
    probability = min(1.0, specification.mean_degree / (count - 1))
    return erdos_renyi(count, probability; rng)
end

function generate_graph(
    rng::AbstractRNG,
    specification::BarabasiAlbertTopology,
    agent_count::Integer,
)
    return barabasi_albert(
        Int(agent_count),
        specification.attachments;
        rng,
    )
end

generate_graph(
    rng::AbstractRNG,
    ::CompleteTopology,
    agent_count::Integer,
) = complete_graph(Int(agent_count))

abstract type InsuranceSpecification end
struct NoInsuranceSpecification <: InsuranceSpecification end

struct FixedInsuranceSpecification <: InsuranceSpecification
    maximum_payment::Float64

    function FixedInsuranceSpecification(maximum_payment::Real)
        value = Float64(maximum_payment)
        value >= 0.0 ||
            throw(ArgumentError("maximum_payment must be nonnegative"))
        new(value)
    end
end

struct QuantileInsuranceSpecification <: InsuranceSpecification
    quantile::Float64

    function QuantileInsuranceSpecification(quantile_value::Real)
        value = Float64(quantile_value)
        0.0 <= value <= 1.0 ||
            throw(ArgumentError("quantile must be in [0, 1]"))
        new(value)
    end
end

struct AdaptiveInsuranceSpecification <: InsuranceSpecification end

resolve_insurance(
    ::NoInsuranceSpecification,
    deposits::AbstractVector{<:Real},
) = NoDepositInsurance()

resolve_insurance(
    specification::FixedInsuranceSpecification,
    deposits::AbstractVector{<:Real},
) = FixedDepositInsurance(specification.maximum_payment)

resolve_insurance(
    specification::QuantileInsuranceSpecification,
    deposits::AbstractVector{<:Real},
) = FixedDepositInsurance(quantile(deposits, specification.quantile))

resolve_insurance(
    ::AdaptiveInsuranceSpecification,
    deposits::AbstractVector{<:Real},
) = AdaptiveDepositInsurance()

function heuristic_deposit_specifications(; target_mean::Real=10.0)
    target = Float64(target_mean)
    lower = 0.1target
    upper = 10.0target
    specifications = DepositSpecification[HomogeneousDeposits(target)]
    for sigma in (0.5, 1.0, 1.5)
        mu = log(target) - sigma^2 / 2
        push!(
            specifications,
            ClippedLogNormalDeposits(mu, sigma, lower, upper, target),
        )
    end
    for alpha in (1.5, 2.0, 3.0)
        scale = target * (alpha - 1.0) / alpha
        push!(
            specifications,
            ClippedParetoDeposits(scale, alpha, lower, upper, target),
        )
    end
    return specifications
end

function heuristic_topology_specifications()
    specifications = TopologySpecification[]
    for degree in (6, 10, 20), probability in (0.05, 0.15, 0.30)
        push!(
            specifications,
            WattsStrogatzTopology(degree, probability),
        )
    end
    append!(
        specifications,
        ErdosRenyiTopology.(Float64.((6, 10, 20))),
    )
    append!(
        specifications,
        BarabasiAlbertTopology.((3, 5, 10)),
    )
    push!(specifications, CompleteTopology())
    return specifications
end

function heuristic_insurance_specifications(; target_mean::Real=10.0)
    target = Float64(target_mean)
    return InsuranceSpecification[
        NoInsuranceSpecification(),
        FixedInsuranceSpecification(0.5target),
        FixedInsuranceSpecification(target),
        QuantileInsuranceSpecification(0.50),
        QuantileInsuranceSpecification(0.90),
        QuantileInsuranceSpecification(0.98),
        AdaptiveInsuranceSpecification(),
    ]
end
