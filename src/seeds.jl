"""
    RunSeed(value)

Root seed for a complete replication run. Every stochastic unit derives its
seed from this value and stable integer coordinates, never from worker IDs or
Julia's session-randomized `hash`.
"""
struct RunSeed
    value::UInt64
end

RunSeed(value::Integer) = RunSeed(UInt64(value))

"""
    derive_seed(run_seed, coordinates...)

Derive a stable 64-bit seed using SplitMix64 mixing. Identical run seeds and
integer coordinates produce identical streams independent of worker assignment.
"""
function derive_seed(run_seed::RunSeed, coordinates::Integer...)
    state = run_seed.value
    for coordinate in coordinates
        state = splitmix64(state ⊻ UInt64(coordinate))
    end
    return state
end

function splitmix64(value::UInt64)
    value += 0x9e3779b97f4a7c15
    value = (value ⊻ (value >> 30)) * 0xbf58476d1ce4e5b9
    value = (value ⊻ (value >> 27)) * 0x94d049bb133111eb
    return value ⊻ (value >> 31)
end
