# convergence_test.jl
#
# Tests whether failProb is monotonically decreasing in K (stochastic dominance
# check). Runs 15 representative tuples spanning failProb ∈ [0.01, 0.97] at
# K = 50, 100, 200. Results written to DDData/convergence_results.csv.
#
# Runtime estimate (16-core Mac, O(K²) scaling from K=50 baseline of 601s):
#   K=50:  15 tuples / 15 workers × 601s  ≈  10 min
#   K=100: 15 tuples / 15 workers × 2404s ≈  40 min
#   K=200: 15 tuples / 15 workers × 9616s ≈ 160 min
#   Total: ≈ 3.5 hours

using Pkg
Pkg.activate("..")
using Distributed

cores = Sys.CPU_THREADS
if nprocs() < cores
    addprocs(cores - nprocs();
             exeflags = "--project=$(Base.active_project())")
end
println("Workers: ", nworkers())
flush(stdout)

@everywhere begin
    using Distributions, Random, DataFrames, CSV
    depth   = 100
    totResr = 1000
end

@everywhere include("objects.jl")
@everywhere include("functions.jl")

# 15 representative tuples from existing K=50 results, spanning failProb ∈ [0.01, 0.97].
# Columns: (insur, prod, objP, approx_failProb_at_K50)
const TEST_TUPLES = [
    (0.55, 0.55, 0.15),   # ≈ 0.01
    (0.60, 0.50, 0.15),   # ≈ 0.02
    (0.60, 0.55, 0.15),   # ≈ 0.02
    (0.55, 0.50, 0.20),   # ≈ 0.21
    (0.50, 0.50, 0.20),   # ≈ 0.11
    (0.55, 0.55, 0.20),   # ≈ 0.13
    (0.60, 0.50, 0.20),   # ≈ 0.41
    (0.50, 0.55, 0.25),   # ≈ 0.44
    (0.50, 0.50, 0.25),   # ≈ 0.56
    (0.55, 0.60, 0.25),   # ≈ 0.61
    (0.55, 0.55, 0.25),   # ≈ 0.75
    (0.55, 0.50, 0.25),   # ≈ 0.77
    (0.60, 0.55, 0.25),   # ≈ 0.81
    (0.60, 0.50, 0.25),   # ≈ 0.91
    (0.50, 0.50, 0.30),   # ≈ 0.97
]

output_file = "../DDData/convergence_results.csv"

# Write header
open(output_file, "w") do f
    write(f, "K,insur,prod,objP,failProb\n")
end

for K in [50, 100, 200]
    @everywhere agtCnt = $K
    t_start = time()
    println("K=$K: starting $(length(TEST_TUPLES)) tuples on $(nworkers()) workers...")
    flush(stdout)

    results = pmap(TEST_TUPLES) do tup
        insur, prod, objP = tup
        # Deterministic seed per (K, insur, prod, objP) for reproducibility.
        Random.seed!(abs(hash((agtCnt, insur, prod, objP))) % 10^9)
        mod = modelGen(agtCnt, objP, insur, prod, 1.0)
        fp  = runMod(mod)
        (agtCnt, insur, prod, objP, fp)
    end

    open(output_file, "a") do f
        for r in results
            write(f, "$(r[1]),$(r[2]),$(r[3]),$(r[4]),$(r[5])\n")
        end
    end

    elapsed = round((time() - t_start) / 60, digits=1)
    println("K=$K done in $elapsed minutes.")
    flush(stdout)
end

println("Complete. Results written to $output_file")
