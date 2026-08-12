abstract type RecoveryOutcome end
struct ZeroRecovery <: RecoveryOutcome end
struct PartialRecovery <: RecoveryOutcome end
struct FullRecovery <: RecoveryOutcome end

function recovery_outcome(payment::Real, full_claim::Real)
    paid = Float64(payment)
    claim = Float64(full_claim)
    claim > 0.0 || throw(ArgumentError("full_claim must be positive"))
    paid >= 0.0 || throw(ArgumentError("payment must be nonnegative"))
    paid == 0.0 && return ZeroRecovery()
    paid >= claim && return FullRecovery()
    return PartialRecovery()
end

function recovery_counts(outcomes::AbstractVector{<:RecoveryOutcome})
    isempty(outcomes) ||
        return RecoveryCounts(
            count(outcome -> outcome isa FullRecovery, outcomes),
            count(outcome -> outcome isa PartialRecovery, outcomes),
            count(outcome -> outcome isa ZeroRecovery, outcomes),
        )
    throw(ArgumentError("at least one recovery outcome is required"))
end

"""
    paired_recovery_counts(withdraw_payments, stay_payments, full_claims)

Classify paired Monte Carlo payments against the same trial-level full-recovery
claims. The two action vectors must have identical lengths, ensuring both bound
models are evaluated from the same underlying trials.
"""
function paired_recovery_counts(
    withdraw_payments::AbstractVector{<:Real},
    stay_payments::AbstractVector{<:Real},
    full_claims::AbstractVector{<:Real},
)
    trial_total = length(withdraw_payments)
    length(stay_payments) == trial_total ||
        throw(ArgumentError("withdraw and stay payments must be paired"))
    length(full_claims) == trial_total ||
        throw(ArgumentError("every paired trial must have a full claim"))
    trial_total > 0 || throw(ArgumentError("at least one paired trial is required"))

    withdraw_outcomes = RecoveryOutcome[
        recovery_outcome(withdraw_payments[index], full_claims[index])
        for index in eachindex(withdraw_payments)
    ]
    stay_outcomes = RecoveryOutcome[
        recovery_outcome(stay_payments[index], full_claims[index])
        for index in eachindex(stay_payments)
    ]
    return PairedRecoveryCounts(
        recovery_counts(withdraw_outcomes),
        recovery_counts(stay_outcomes),
    )
end
