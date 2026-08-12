using Pkg
Pkg.activate("..")
Pkg.instantiate()
using Distributed
@everywhere begin
    import Pkg
    Pkg.activate("..")  # Must be absolute
    using Random  # Now it will be found
end
@everywhere using Distributions
@everywhere using Random
@everywhere using DataFrames
@everywhere using TreeParzen
@everywhere using JLD2

@everywhere using CSV
@everywhere agtCnt=50
@everywhere depth=100
@everywhere totResr::Int64=1000
# now how many runs per model type?
@everywhere runCnt=100
@everywhere include("objects.jl")
@everywhere include("functions.jl")
# now set a seed for the main process
Random.seed!(56888923)

# detect availabile cores
cores=Sys.CPU_THREADS

# now have the code fail immediately if the /scratch is not accessible
#if !isdir("/scratch/jschule4")
#    error("The /scratch/jschule4 directory is not accessible. Please check your environment setup.")
#end



#now, generate the possible values of insurance and production
tuples=[]

for insur in 0.5:0.05:0.6
    for prod in 0.5:0.05:0.6
        for objP in 0.0:0.05:1.0
            push!(tuples,(insur,prod,objP))
        end
    end
end
# generate a seed for each tuple
X=DiscreteUniform(1,1000000000)
allSeeds=rand(X,length(tuples))


# count completed processes
procCnt=length(tuples)
doneCnt=0
coreDict=Dict()
for coreNum in 2:cores
    coreDict[coreNum] = nothing
end

# testing 


# now we run the process
while doneCnt < procCnt
    for c in keys(coreDict)
        # if the core contains nothing, send it an optimization procedure
        if isnothing(coreDict[c]) && length(tuples) > 0
            currTup=popfirst!(tuples)
            println("Sending tuple "*string(currTup)*" to core "*string(c))
            println(length(tuples))
            coreDict[c]=@spawnat c begin
                Random.seed!(pop!(allSeeds))
                runFamily(currTup[1],currTup[2],currTup[3])
            end
        elseif isReady(coreDict[c])
            result=fetch(coreDict[c])
            global doneCnt
            doneCnt=doneCnt+1
            coreDict[c]=nothing
        end
    end
end