################################################################################
# Small-epsilon sweep for AREx model                                           #
# Sweeps insur in [0.0, 0.02, ..., 0.1] to populate the bridge-theorem regime #
# Output: ../DDData/results_smallEps.csv  (insur, prod, objP, failProb)        #
################################################################################

using Pkg
Pkg.activate("..")
Pkg.instantiate()
using Distributed

@everywhere begin
    import Pkg
    Pkg.activate("..")
    using Random
end
@everywhere using Distributions
@everywhere using Random
@everywhere using DataFrames
@everywhere using CSV

@everywhere agtCnt  = 50
@everywhere depth   = 100
@everywhere totResr::Int64 = 1000

@everywhere include("objects.jl")
@everywhere include("functions.jl")

# Separate output file so small-eps data stays distinct from the main sweep.
@everywhere const SMALL_EPS_OUT = "../DDData/results_smallEps.csv"

@everywhere function runFamilySmall(insur::Float64, prod::Float64, objP::Float64)
    global agtCnt, depth, totResr
    mod    = modelGen(agtCnt, objP, insur, prod, 1.0)
    result = runMod(mod)
    df     = DataFrame(insur=insur, prod=prod, objP=objP, failProb=result)
    CSV.write(SMALL_EPS_OUT, df, header=false, append=true)
    return (result, insur, prod, objP)
end

Random.seed!(99887766)
cores = Sys.CPU_THREADS

tuples = Tuple{Float64,Float64,Float64}[]
for insur in 0.0:0.02:0.1
    for prod in 0.5:0.05:0.6
        for objP in 0.0:0.05:1.0
            push!(tuples, (insur, prod, objP))
        end
    end
end

println("Total tuples: ", length(tuples))

X        = DiscreteUniform(1, 1_000_000_000)
allSeeds = rand(X, length(tuples))

procCnt  = length(tuples)
doneCnt  = 0
coreDict = Dict{Int,Any}(c => nothing for c in 2:cores)

while doneCnt < procCnt
    for c in keys(coreDict)
        if isnothing(coreDict[c]) && length(tuples) > 0
            currTup     = popfirst!(tuples)
            theSeed     = pop!(allSeeds)
            println("Core $c ← $currTup  ($(length(tuples)) left)")
            coreDict[c] = @spawnat c begin
                Random.seed!(theSeed)
                runFamilySmall(currTup[1], currTup[2], currTup[3])
            end
        elseif isReady(coreDict[c])
            fetch(coreDict[c])
            global doneCnt
            doneCnt        += 1
            coreDict[c]    = nothing
        end
    end
end

println("Done. Wrote $(procCnt) rows to $SMALL_EPS_OUT")
