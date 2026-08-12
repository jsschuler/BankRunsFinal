abstract type DecisionModel end

struct BridgeThreshold <: DecisionModel
    threshold::Float64

    function BridgeThreshold(threshold::Real)
        value = Float64(threshold)
        0.0 <= value <= 1.0 ||
            throw(ArgumentError("threshold must be in [0, 1]"))
        new(value)
    end
end

struct RelativeSafety <: DecisionModel end

struct CRRARiskNeutral <: DecisionModel
    gross_return::Float64

    function CRRARiskNeutral(gross_return::Real)
        value = Float64(gross_return)
        value > 1.0 || throw(ArgumentError("gross_return must exceed one"))
        new(value)
    end
end

struct ExplicitUtility <: DecisionModel
    rho::Float64
    gross_return::Float64

    function ExplicitUtility(rho::Real, gross_return::Real)
        risk_aversion = Float64(rho)
        return_value = Float64(gross_return)
        risk_aversion >= 0.0 ||
            throw(ArgumentError("rho must be nonnegative"))
        return_value > 1.0 ||
            throw(ArgumentError("gross_return must exceed one"))
        new(risk_aversion, return_value)
    end
end

abstract type PartialConvention end
struct PartialAsZero <: PartialConvention end
struct PartialAsFull <: PartialConvention end

abstract type PartialPaymentBound end
struct FullRecoveryOnly <: PartialPaymentBound end
struct WithdrawalFavoringBound <: PartialPaymentBound end
struct StayingFavoringBound <: PartialPaymentBound end

struct RecoveryCounts
    full::Int
    partial::Int
    zero::Int

    function RecoveryCounts(full::Integer, partial::Integer, zero::Integer)
        minimum((full, partial, zero)) >= 0 ||
            throw(ArgumentError("recovery counts must be nonnegative"))
        full + partial + zero > 0 ||
            throw(ArgumentError("at least one recovery outcome is required"))
        new(Int(full), Int(partial), Int(zero))
    end
end

struct PairedRecoveryCounts
    withdraw::RecoveryCounts
    stay::RecoveryCounts

    function PairedRecoveryCounts(
        withdraw::RecoveryCounts,
        stay::RecoveryCounts,
    )
        withdraw_trials = trial_count(withdraw)
        stay_trials = trial_count(stay)
        withdraw_trials == stay_trials ||
            throw(ArgumentError("withdraw and stay must use the same trial count"))
        new(withdraw, stay)
    end
end

struct RecoveryProbabilities
    p_full_if_withdraw::Float64
    p_full_if_stay::Float64

    function RecoveryProbabilities(
        p_full_if_withdraw::Real,
        p_full_if_stay::Real,
    )
        p_w = Float64(p_full_if_withdraw)
        p_s = Float64(p_full_if_stay)
        0.0 <= p_w <= 1.0 ||
            throw(ArgumentError("withdrawal recovery probability must be in [0, 1]"))
        0.0 <= p_s <= 1.0 ||
            throw(ArgumentError("staying recovery probability must be in [0, 1]"))
        new(p_w, p_s)
    end
end

struct BoundDecision{B<:PartialPaymentBound,D<:DecisionModel}
    bound::B
    decision_model::D
    probabilities::RecoveryProbabilities
    withdraw::Bool
end

trial_count(counts::RecoveryCounts) =
    counts.full + counts.partial + counts.zero

recovery_probability(counts::RecoveryCounts, ::PartialAsZero) =
    counts.full / trial_count(counts)

recovery_probability(counts::RecoveryCounts, ::PartialAsFull) =
    (counts.full + counts.partial) / trial_count(counts)

function recovery_probabilities(
    counts::PairedRecoveryCounts,
    ::FullRecoveryOnly,
)
    return RecoveryProbabilities(
        recovery_probability(counts.withdraw, PartialAsZero()),
        recovery_probability(counts.stay, PartialAsZero()),
    )
end

function recovery_probabilities(
    counts::PairedRecoveryCounts,
    ::WithdrawalFavoringBound,
)
    return RecoveryProbabilities(
        recovery_probability(counts.withdraw, PartialAsFull()),
        recovery_probability(counts.stay, PartialAsZero()),
    )
end

function recovery_probabilities(
    counts::PairedRecoveryCounts,
    ::StayingFavoringBound,
)
    return RecoveryProbabilities(
        recovery_probability(counts.withdraw, PartialAsZero()),
        recovery_probability(counts.stay, PartialAsFull()),
    )
end

"""
    should_withdraw(probabilities, decision_model)

Apply a typed withdrawal rule. Every method first applies the certainty rule:
an agent does not withdraw when full recovery from staying is certain.
"""
function should_withdraw(
    probabilities::RecoveryProbabilities,
    model::BridgeThreshold,
)
    probabilities.p_full_if_stay == 1.0 && return false
    return (
        probabilities.p_full_if_stay <=
        probabilities.p_full_if_withdraw * model.threshold
    )
end

network_utility(consumption::Float64, rho::Float64) =
    rho == 1.0 ?
    log1p(max(0.0, consumption)) :
    (1.0 + max(0.0, consumption))^(1.0 - rho) / (1.0 - rho)

function should_withdraw(
    withdraw_payments::AbstractVector{<:Real},
    stay_payments::AbstractVector{<:Real},
    model::ExplicitUtility,
)
    length(withdraw_payments) == length(stay_payments) ||
        throw(ArgumentError("withdraw and stay payments must be paired"))
    isempty(withdraw_payments) &&
        throw(ArgumentError("at least one paired payment is required"))
    withdraw_utility = mean(
        payment -> network_utility(Float64(payment), model.rho),
        withdraw_payments,
    )
    stay_utility = mean(
        payment -> network_utility(
            model.gross_return * Float64(payment),
            model.rho,
        ),
        stay_payments,
    )
    return withdraw_utility > stay_utility
end

function should_withdraw(
    probabilities::RecoveryProbabilities,
    ::RelativeSafety,
)
    probabilities.p_full_if_stay == 1.0 && return false
    return probabilities.p_full_if_withdraw > probabilities.p_full_if_stay
end

function should_withdraw(
    probabilities::RecoveryProbabilities,
    model::CRRARiskNeutral,
)
    probabilities.p_full_if_stay == 1.0 && return false
    return (
        probabilities.p_full_if_stay <=
        probabilities.p_full_if_withdraw / model.gross_return
    )
end

function evaluate_bound(
    bound::PartialPaymentBound,
    decision_model::DecisionModel,
    counts::PairedRecoveryCounts,
)
    probabilities = recovery_probabilities(counts, bound)
    return BoundDecision(
        bound,
        decision_model,
        probabilities,
        should_withdraw(probabilities, decision_model),
    )
end

function evaluate_bounds(
    decision_model::DecisionModel,
    counts::PairedRecoveryCounts,
)
    return (
        evaluate_bound(WithdrawalFavoringBound(), decision_model, counts),
        evaluate_bound(StayingFavoringBound(), decision_model, counts),
    )
end

bound_name(::WithdrawalFavoringBound) = "withdrawal_favoring"
bound_name(::StayingFavoringBound) = "staying_favoring"
bound_name(::FullRecoveryOnly) = "full_recovery_only"
