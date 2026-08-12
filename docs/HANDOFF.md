# BankRunsFinal handoff

Last updated: 2026-07-24

## Sign-off status: confirmatory frozen; monotonicity runner validated

The staged network run is currently:

```text
convergence: 17,280 / 17,280, merged and frozen
selected subjective draws: 500
coverage: 141,120 / 141,120, merged and frozen
adaptive batch 1: 150,000 / 150,000, merged and frozen
confirmatory selection: 80 learned cells, frozen
confirmatory execution: 96,000 / 96,000, merged and frozen
monotonicity implementation: complete and tested
monotonicity production design: not yet prepared or frozen
monotonicity execution: 0 / 39,600
```

The confirmatory merge passed integrity checks: 96,000 unique job IDs, all 80
selected structural cells, 400 replications for each of the three decision
models in every cell, selection-index agreement, and no invalid timing values.
The frozen marker records `jobs=96000` and `run_seed=20260723`.

Adaptive batch 1 contains 500 replications per decision model for each of 100
coverage-selected structural cells. Its merged output passed integrity checks:
all 150,000 job IDs are unique, every structural cell has 1,500 rows, no
numeric outcome fields are invalid, and no above-par payments occur.

The confirmatory selector now learns from these adaptive outcomes rather than
copying the pre-adaptive selection. It combines beta-binomial posterior
failure entropy, disagreement across decision models, posterior uncertainty,
and observed runtime. A deterministic greedy diversity bonus maintains
representation across the design categories available in the adaptive pool.
The resulting 80-cell manifest is frozen with SHA-256 hashes of the scores and
selection. Confirmatory jobs use stage-specific seeds not used for selection.

The learned set is concentrated near the empirical boundary: 68 cells have
reserve ratio 0.20, 11 have 0.30, and one has 0.40. This is intentional for
boundary confirmation. It is not the design used to establish monotonic
comparative statics; a separate balanced, prespecified monotonicity sweep is
planned after confirmatory execution.

The 9,000-model fixed-structure initial-condition experiment is complete:

```text
model runs: 9,000
fixed structure/model cells: 180
cells with failure-outcome flips: 165
structural realizations with at least one model flip: 59 / 60
median within-cell withdrawal range: 286 agents
maximum within-cell withdrawal range: 433 agents
```

Holding deposits, graph, parameters, and decision model fixed, changing only
the initially withdrawing agents changes bank failure in 91.7% of the tested
structure/model cells. This confirms that initial-withdrawer identity is a
material knife-edge dimension rather than noise introduced by jointly
regenerating the model structure.

Merged coverage output:

```text
runs/network_20260723/coverage/results.csv
```

Coverage completed in approximately 1 hour 55 minutes. Recorded mean runtime
was 0.607 seconds per model, the median was 0.365 seconds, and 81.4% of runs
had no endogenous withdrawals. The earlier 3–6 second planning mean was
deliberately conservative; all 141,120 unique jobs are present.

The expected aggregate gradients hold:

- failure falls from 8.26% to 2.13% to 0.68% as reserves rise from 0.20 to
  0.30 to 0.40;
- ten-agent shocks fail more often than one-agent shocks, 6.47% versus 0.92%;
- localized shocks fail more often than random shocks, 4.69% versus 2.70%;
- no above-par payments occur.

The comparative model makes more withdrawals but has fewer exact failures in
the full heterogeneous grid. A matched diagnostic confirmed that claimant
identity and deposit size are material: in 2,177 of 3,985 cases where the
comparative model survived and a comparator failed, it made more withdrawals
while retaining more vault value. All 3,985 reversals used heterogeneous
deposits.

Near exhaustion is expected under the model architecture and is not treated as
a defect. Exact failure remains `final_vault <= 0`; reporting should retain
near-depletion measures alongside it. The primary research interest is
knife-edge sensitivity to initial conditions.

The five coverage replications cannot isolate that estimand because each
replication jointly regenerates deposits, the graph, and the initial shock.
`scripts/initial_condition_sensitivity.jl` therefore implements a separate
fixed-structure design:

- deposits and graph are fixed by a structure seed;
- only initial-withdrawer identity/location changes across shock trials;
- the same shock and model seed are used across all three decision models;
- failure flips and withdrawal dispersion are measured within each fixed
  structure/model cell.

The bounded plumbing validation and the full 9,000-model experiment passed, as
did the full package test suite. The final outputs are:

```text
runs/network_20260723/initial_conditions/results.csv
runs/network_20260723/initial_conditions/results_cells.csv
runs/network_20260723/initial_conditions/results_report.md
```

### Next commands

After signing in, adopt the tested monotonicity runner source fingerprint,
materialize the prespecified design and hypotheses, and freeze them:

```sh
julia --project=. scripts/network_experiment.jl \
  adopt-monotonicity runs/network_20260723
julia --project=. scripts/network_experiment.jl \
  prepare-monotonicity runs/network_20260723
julia --project=. scripts/network_experiment.jl \
  freeze-monotonicity-design runs/network_20260723
```

Inspect `runs/network_20260723/monotonicity/design.csv`,
`hypotheses.csv`, and `DESIGN_FROZEN`, then launch:

```sh
nohup julia --project=. scripts/network_experiment.jl \
  run monotonicity runs/network_20260723 \
  --workers 16 \
  --replications 200 \
  > runs/network_20260723/monotonicity-run.log 2>&1 &
```

The 39,600-job run is estimated at approximately 1.5 hours by proportional
scaling from confirmatory execution; allow 1.5–2.5 wall-clock hours for startup
and runtime-tail imbalance.

Detailed diagnostic findings and design decisions are recorded in
`docs/IMPLEMENTATION_LOG.md`.

## Repository

Location:

```text
/Users/l25-n05917-res/ResearchCode/BankRunsFinal
```

This is a new local Git repository intended to become the public replication
repository. It has not been committed, connected to a GitHub remote, or pushed.

The original repositories remain unchanged:

```text
/Users/l25-n05917-res/ResearchCode/BankRuns5
/Users/l25-n05917-res/ResearchCode/DiamondDybvig
```

Exact source snapshots were copied into:

```text
legacy/network/
legacy/dd/
```

## Agreed model decisions

### Reproducibility and parallelism

- Use process-based parallelism.
- Run one complete model at a time on each worker.
- Use `pmap` with `batch_size=1`.
- Workers return buffered results.
- Only the master process writes output.
- A logged run seed determines stable model seeds.
- Seeds do not depend on worker IDs or scheduling.
- Determinism is targeted for a fixed architecture and Julia environment.

### Network-model decision modes

Three modes were agreed:

1. `BridgeThreshold`:

   ```text
   p_full_if_stay <= p_full_if_withdraw * threshold
   ```

2. `RelativeSafety`:

   ```text
   p_full_if_withdraw > p_full_if_stay
   ```

3. `CRRARiskNeutral`:

   ```text
   p_full_if_stay <= p_full_if_withdraw / gross_return
   ```

Every mode first applies the certainty rule: an agent does not withdraw when
`p_full_if_stay == 1`.

Risk neutrality is the CRRA limit `rho = 0`; `rho = 1` is log utility.

### Partial payments

Monte Carlo recovery is represented as zero, partial, or full. A partial
payment can be classified as zero or full to construct finite-agent bounds.

The withdrawal-favoring bound classifies:

- partial withdrawal as full;
- partial staying recovery as zero.

The staying-favoring bound classifies:

- partial withdrawal as zero;
- partial staying recovery as full.

This bounding exercise belongs primarily to the stochastic DD validation
between the bridge theorem and the network simulation.

### Network information and activation

- Realized withdrawals are sequential.
- An agent has a definite realized activation position.
- The agent does not observe its global queue position.
- It treats withdrawn neighbors as a representative sample of withdrawals.
- It is uncertain about unobserved preceding withdrawals and subsequent
  withdrawals.
- Actual model state and subjective agent information must remain distinct.

The legacy network code has two confirmed state problems that have not yet
been repaired in the new implementation:

1. Its `simModel` snapshot is created after exogenous withdrawals and never
   refreshed after endogenous withdrawals.
2. Observed withdrawn neighbors can be withdrawn a second time inside a
   subjective simulation, subtracting their deposits from the simulated vault
   twice.

## Completed implementation

### Julia package

Created:

```text
Project.toml
Manifest.toml
src/BankRunsFinal.jl
src/seeds.jl
src/decisions.jl
src/dd.jl
test/runtests.jl
scripts/run_dd_core.jl
```

The manifest is intentionally trackable for replication.

### Stable seed hierarchy

`RunSeed` and `derive_seed` use stable SplitMix64 mixing. Julia's
session-dependent `hash` and worker IDs are not used.

### Decision and partial-payment infrastructure

The three network decision modes, certainty rule, recovery counts, recovery
probabilities, and partial-payment conventions are implemented and tested.
They are represented by immutable struct types and selected through multiple
dispatch. There are no enum switches controlling model behavior.

`WithdrawalFavoringBound` and `StayingFavoringBound` consume the same
`PairedRecoveryCounts`. Trial-level payments are classified as zero, partial,
or full by `paired_recovery_counts`, and
`scripts/report_recovery_bounds.jl` produces separately labelled bound output.

### Corrected subjective-state core

`src/network.jl` implements fresh subjective snapshots, typed withdrawal/stay
actions, typed deposit-insurance models, and paired recovery payments. New
snapshots include every objective withdrawal made before the current decision.
Already-withdrawn agents are skipped in simulated future withdrawal orders, so
their deposits cannot be subtracted twice.

The activation loop now has three concrete model types sharing
`run_network_model`: comparative recovery probability, bridge threshold, and
explicit expected utility. Payments are capped at par for every model.

The post-sampler common-scenario validation contains 1,800 results. All three
models agree on failure in 84.5% of matched scenarios and all display a sharply declining
failure gradient as reserves rise. Threshold and explicit-utility results are
close (failure rates 0.082 and 0.087); the comparative rule is more sensitive
(0.237). No above-par payments occur.

Output:

```text
output/network_validation_sparse_sampler_seed20260723.csv
```

### Dual network execution representations

Every economic network model can be wrapped in either:

- `SmallObjectNetworkModel`, which clones full subjective states for debugging;
- `LargeSparseNetworkModel`, which shares objective deposits and represents
  subjective futures with sparse withdrawal-index vectors.

Exact parity tests cover all three economic models, heterogeneous deposits,
and fixed insurance. The 1,000-agent benchmark reduced subjective-payment
allocations from 17.5 MB to 16.3 KB and was approximately 94 times faster. The
complete sparse validation output is byte-for-byte identical to the
small-object validation.

### Typed production parameter generators

`src/network_parameters.jl` contains distinct structs for homogeneous,
clipped-LogNormal, and clipped-Pareto deposits; Watts–Strogatz, Erdős–Rényi,
Barabási–Albert, and complete topologies; and no, fixed, quantile, and adaptive
insurance. Shared generation functions use multiple dispatch. The initial
heuristic grids and clipping/normalization choices are recorded in
`docs/IMPLEMENTATION_LOG.md`.

### Resumable staged experiment runner

`scripts/network_experiment.jl` implements initialization, typed convergence
and coverage execution, adaptive selection/batches, confirmatory execution,
atomic chunks, merge, freeze, status, and resume. Stable matched seeds and
explicit freeze boundaries prevent later stages from silently changing earlier
design choices. See `docs/NETWORK_RUN_PLAN.md` and the README for commands.

### Distinct stochastic DD bridge model

`src/dd_bridge.jl` is the theorem-facing finite-agent model. Its state and
action types are distinct from every network type. It generates paired
withdraw/stay counterfactual payments from the same draw of other agents'
future withdrawals.

The 180-scenario bridge sweep uses 10,000 paired trials per scenario and the
binary-recovery payoff threshold
`(1 + withdrawal_premium) / (1 + withdrawal_premium + productivity)`.
The two partial-payment bounds agree in 153 scenarios: 75 prescribe withdrawal
and 78 prescribe staying. They disagree in 27 scenarios.

Output:

```text
output/dd_bridge_bounds_seed20260723.csv
```

### Corrected DD conditional sampler

The legacy DD code conditions incorrectly around the observed withdrawal count.
The new implementation samples:

```text
X ~ Binomial(K, p0) | X >= observed
```

using the correct conditional inverse CDF.

The original behavior remains untouched in `legacy/dd`.

### Paired DD preference sweep

The new DD implementation supports:

- `rho = 1.0`: shifted log utility;
- `rho = 0.0`: risk-neutral CRRA limit.

For every parameter tuple, it:

1. searches every initial deposit allocation;
2. runs 1,000 realized models for every candidate allocation;
3. selects the allocation with the highest simulated expected utility;
4. estimates failure at that allocation with an independent 10,000-realization
   holdout sample.

The initial search is the approximate-rational-expectations component of the
model. The principal comparative result to validate is that failure rate rises
monotonically with the withdrawal payout.

The withdrawal probability is the agent's prior over total eventual
withdrawals, not a prior restricted to exogenous withdrawals. Agents condition
future total withdrawals on those already observed, including the focal
agent's own withdrawal when evaluating that action.

Search and holdout streams are separate. Within matched `rho`, productivity,
and withdrawal-probability groups, withdrawal-premium comparisons use common
random-number seeds.

The new implementation currently preserves the legacy payoff parameterization:

```text
early withdrawal multiplier = 1 + withdrawal_premium
late multiplier = 1 + withdrawal_premium + productivity
```

The final high-precision DD core sweep completed successfully with 360
parameter jobs and run seed `20260723`. The default total-withdrawal
probability grid is `0.05:0.05:1.0`; the economically unsupported
zero-probability endpoint is excluded.

The independent holdout results are nondecreasing in the withdrawal premium
for all 120 matched parameter groups. There are no decreases. Mean failure
rates rise from approximately 0.696 to 0.721 to 0.748 as the premium rises
from 0.50 to 0.55 to 0.60 for both preference specifications. The largest 95%
Wilson interval half-width is 0.0094.

## Validation completed

The full package test command passes:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```

There are currently 213 passing tests covering:

- stable seed derivation;
- corrected conditioned-Binomial sampling;
- boundary cases for the sampler;
- paired `rho` job construction;
- deterministic DD allocation-search smoke test;
- independent holdout evaluation;
- common random numbers across withdrawal-premium comparisons;
- partial-payment classifications;
- paired withdrawal/staying trial enforcement;
- typed withdrawal- and staying-favoring bounds;
- refreshed subjective snapshots;
- prevention of double withdrawal in subjective simulations;
- all three withdrawal modes;
- the certainty rule.

The final DD output and automated report are:

```text
output/dd_core_final_seed20260723.csv
output/dd_core_final_seed20260723_report_rates.csv
output/dd_core_final_seed20260723_report_monotonicity.csv
output/dd_core_final_seed20260723_report_summary.txt
```

## Launching the DD core sweep

From the repository root:

```sh
cd /Users/l25-n05917-res/ResearchCode/BankRunsFinal
mkdir -p output
julia --project=. scripts/run_dd_core.jl 20260723 \
  output/dd_core_final_seed20260723.csv
julia --project=. scripts/report_dd_core.jl \
  output/dd_core_final_seed20260723.csv \
  output/dd_core_final_seed20260723_report
```

The first argument is the run seed. Preserve it in the replication record.

For a detached run:

```sh
cd /Users/l25-n05917-res/ResearchCode/BankRunsFinal
mkdir -p output
nohup julia --project=. scripts/run_dd_core.jl 20260723 \
  output/dd_core_final_seed20260723.csv \
  > output/dd_core_final_seed20260723.log 2>&1 &
```

The sweep contains 360 parameter jobs:

```text
2 rho values
3 withdrawal premia
3 productivity values
20 total-withdrawal prior probabilities (`0.05:0.05:1.0`)
```

Each job searches 101 allocations with 1,000 realizations per allocation and
then evaluates the selected allocation on 10,000 independent holdout
realizations.

## Remaining work

1. Adopt the validated runner migration, prepare, inspect, and freeze the
   prespecified monotonicity design.
2. Run, merge, validate, and freeze the 39,600-job monotonicity sweep.
3. Generate confirmatory and monotonicity tables, uncertainty intervals, and
   figure-reproduction scripts.
4. Add optional trial-level paired recovery output for diagnostic runs.
5. Consider off-grid TPE proposals as an optional extension, not a prerequisite
   for the frozen confirmatory analysis.
6. Reconcile paper terminology and reported replication counts.
7. Commit the repository, create the GitHub remote, and push only after review.
