# BankRunsFinal

Unified replication code for the stochastic Diamond–Dybvig and
network-contagion bank-run models.

The repository is being rebuilt from immutable snapshots in `legacy/`.
New implementation code lives in `src/`; replication entry points live in
`scripts/`; tests live in `test/`. Original projects are not modified.

## Reproducibility contract

- A single logged run seed determines every model and Monte Carlo seed.
- Seeds are derived from stable integer coordinates, never worker IDs.
- Worker scheduling therefore does not change model-level random streams.
- Each worker runs one complete model at a time through process-based `pmap`.
- Workers return buffered records; only the master process writes files.
- Output records include the run seed, derived model seed, model parameters,
  simulation counts, seed design, evaluation design, and Julia version.

The implementation targets Julia 1.11 on a fixed architecture. A checked-in
manifest and full replication commands will be added after the model
reconciliation and validation work is complete.

## Stochastic DD core sweep

Run the paired log-utility and risk-neutral sweep with:

```sh
julia --project=. scripts/run_dd_core.jl 20260723 output/dd_core_final_seed20260723.csv
```

For every parameter tuple and each `rho` in `{1.0, 0.0}`, the program searches
the complete initial deposit grid using 1,000 realized models per candidate.
This initial search is the model's approximate-rational-expectations step. It
then estimates failure at the selected allocation with an independent
10,000-realization holdout sample, giving a worst-case 95% binomial margin of
approximately one percentage point.

The withdrawal probability parameter defines the agent's prior over total
eventual withdrawals. Agents condition that prior on the withdrawals already
observed; a focal agent considering withdrawal includes itself in that lower
bound. The default grid is `0.05:0.05:1.0`; zero is excluded because it has no
economic role in this exercise.

The new implementation corrects the legacy conditional-Binomial off-by-one:
belief draws condition on total withdrawals being at least the observed count.
The sampler normalizes the finite conditional support in log space so small
positive upper tails do not disappear through floating-point cancellation.
The original implementation remains unchanged in `legacy/dd`.

Stable common-random-number seeds are shared across withdrawal-premium values
within each matched `rho`, productivity, and withdrawal-probability group.
Holdout streams are separate from allocation-search streams.

Generate the statistical report with:

```sh
julia --project=. scripts/report_dd_core.jl \
  output/dd_core_final_seed20260723.csv \
  output/dd_core_final_seed20260723_report
```

## Decision modes

The network model supports three preregistered rule types:

1. `BridgeThreshold(threshold)`: `p_stay <= p_withdraw * threshold`.
2. `RelativeSafety()`: `p_withdraw > p_stay`.
3. `CRRARiskNeutral(gross_return)`:
   `p_stay <= p_withdraw / gross_return`.

All modes first apply the certainty rule: an agent does not withdraw when
its estimated probability of full recovery from staying is one.

Monte Carlo recovery is recorded as zero, partial, or full. Partial payments
are evaluated by two model types using the same paired trial draws:

- `WithdrawalFavoringBound()` maps partial withdrawal to full and partial
  staying recovery to zero.
- `StayingFavoringBound()` maps partial withdrawal to zero and partial staying
  recovery to full.

Decision rules, insurance rules, action simulations, and partial-payment bounds
are immutable struct types selected through multiple dispatch. Shared
operations retain one function name (`should_withdraw`,
`recovery_probabilities`, and `simulate_recovery`) rather than branching on
mode flags.

The corrected subjective network state is rebuilt from the current objective
state for every decision. It therefore includes prior endogenous withdrawals.
Subjective future-withdrawal orders skip agents who have already withdrawn,
preventing the legacy double subtraction.

Three separate concrete network model types share `run_network_model`:

- `ComparativeNetworkModel` compares full-recovery probabilities;
- `ThresholdNetworkModel` applies the bridge-style probability threshold;
- `ExplicitUtilityNetworkModel` compares expected shifted-CRRA utility from
  the paired payment draws.

Bank payments are capped at par in every model. The explicit utility model's
late-return parameter changes the value of waiting, not the bank payment.
The post-sampler 1,800-run validation finds 84.5% matched failure-outcome
agreement. The threshold and explicit-utility failure rates are close (`0.082`
and `0.087`); the comparative rule is more sensitive (`0.237`) but exhibits the same strong
decline in runs as reserves increase.

Each economic model can use one of two execution objects:

- `SmallObjectNetworkModel(economic_model)` clones complete subjective states
  for easy inspection and debugging.
- `LargeSparseNetworkModel(economic_model)` shares deposits and represents a
  subjective future by its vault scalar and sparse withdrawal-index vector.

Both use `run_network_model` and produce identical results under the same seed.
On the recorded 1,000-agent benchmark, the sparse subjective payment engine
reduced allocations by roughly 1,077 times and was approximately 94 times
faster. Production validation uses `LargeSparseNetworkModel`.

The production withdrawal sampler maintains active agents with swap-delete
bookkeeping. After drawing `k`, it samples exactly `k` active ranks without
replacement using Floyd sampling, or samples the smaller complement when
`k` is large. It never generates a full eligible-agent permutation. In the
recorded 1,000-agent order-generation benchmark, this reduced allocations by
8.4 times and improved focused runtime by approximately 7.7 times.

## Typed network parameter generators

Production parameters are immutable specification structs:

- deposits: homogeneous, clipped LogNormal, and clipped Pareto;
- topology: Watts–Strogatz, Erdős–Rényi, Barabási–Albert, and complete;
- insurance: none, fixed absolute coverage, realized-deposit quantile
  coverage, and adaptive coverage.

The shared interfaces are `generate_deposits`, `generate_graph`, and
`resolve_insurance`. `heuristic_deposit_specifications`,
`heuristic_topology_specifications`, and
`heuristic_insurance_specifications` return the current documented pilot grid.
All deposit families target mean 10 and heterogeneous draws are clipped to
`[1, 100]`.

## Staged network experiments

The resumable experiment runner uses typed `ConvergenceStage`,
`CoverageStage`, `AdaptiveStage`, and `ConfirmatoryStage` objects. Initialize
and inspect a run with:

```sh
julia --project=. scripts/network_experiment.jl init runs/network_20260723 20260723
julia --project=. scripts/network_experiment.jl status runs/network_20260723
```

Run, merge, and freeze convergence:

```sh
julia --project=. scripts/network_experiment.jl run convergence runs/network_20260723
julia --project=. scripts/network_experiment.jl merge convergence runs/network_20260723
julia --project=. scripts/network_experiment.jl freeze convergence runs/network_20260723
julia --project=. scripts/network_experiment.jl set-draws runs/network_20260723 500
```

Coverage cannot start until convergence is complete and frozen. Every command
is resumable: completed job IDs are read from atomic CSV chunks and skipped.
Use `--limit N` for smoke tests or bounded work sessions.

After frozen coverage, `select-adaptive` ranks discrete grid cells using
beta-binomial failure entropy, model disagreement, uncertainty, and a runtime
penalty. Adaptive batches and the final confirmatory stage consume frozen
selection manifests. After the adaptive batch is merged and frozen,
`select-confirmatory` relearns scores from the high-replication adaptive
outcomes and applies a deterministic diversity-aware selection across deposit,
topology, insurance, reserve, shock-size, and shock-location categories.
Confirmatory jobs use new stage-specific seeds.

For a run created before confirmatory selection learning was added, record the
runner-only fingerprint migration and create the learned 80-cell selection:

```sh
julia --project=. scripts/network_experiment.jl \
  adopt-selection-learning runs/network_20260723
julia --project=. scripts/network_experiment.jl \
  select-confirmatory runs/network_20260723 --cells 80
julia --project=. scripts/network_experiment.jl \
  freeze-selection runs/network_20260723
```

Off-grid TPE proposals remain a later extension of this stage interface.

The current production run has frozen convergence, coverage, adaptive batch 1,
and an 80-cell confirmatory selection learned from the adaptive results. The
confirmatory stage contains 96,000 jobs:

```sh
nohup julia --project=. scripts/network_experiment.jl \
  run confirmatory runs/network_20260723 \
  --workers 16 \
  --replications 400 \
  > runs/network_20260723/confirmatory-run.log 2>&1 &
```

After confirmation, a smaller prespecified monotonicity sweep will evaluate
matched one-factor paths in reserves, fixed insurance coverage, and shock
size. It is kept separate from adaptive selection so its comparative-static
claims come from a balanced design rather than outcome-selected cells.

Adopt the runner extension, materialize the six prespecified structures and
three directional hypotheses, and freeze both files before execution:

```sh
julia --project=. scripts/network_experiment.jl \
  adopt-monotonicity runs/network_20260723
julia --project=. scripts/network_experiment.jl \
  prepare-monotonicity runs/network_20260723
julia --project=. scripts/network_experiment.jl \
  freeze-monotonicity-design runs/network_20260723
```

Then launch the 39,600-job sweep:

```sh
nohup julia --project=. scripts/network_experiment.jl \
  run monotonicity runs/network_20260723 \
  --workers 16 \
  --replications 200 \
  > runs/network_20260723/monotonicity-run.log 2>&1 &
```

The runner is resumable. After completion, merge and freeze with:

```sh
julia --project=. scripts/network_experiment.jl \
  merge monotonicity runs/network_20260723
julia --project=. scripts/network_experiment.jl \
  freeze monotonicity runs/network_20260723
```

Run the validation with:

```sh
julia --project=. scripts/run_network_validation.jl \
  20260723 output/network_validation_seed20260723.csv
```

Given a paired-trial CSV, produce the two bound results with:

```sh
julia --project=. scripts/report_recovery_bounds.jl \
  recovery_trials.csv recovery_bounds.csv
```

Required payment columns are `withdraw_payment`, `stay_payment`, and
`full_claim`; all other non-trial columns identify scenarios.

## Stochastic DD bridge model

The theorem-facing finite-agent model is separate from the network simulation.
`FiniteAgentDDBridgeModel` has homogeneous DD primitives, sequential service,
and distinct `DDBridgeWithdrawNow` and `DDBridgeStay` action types. Each Monte
Carlo draw of other agents' withdrawals is shared by both counterfactuals.

Run its two-bound validation with:

```sh
julia --project=. scripts/run_dd_bridge_bounds.jl \
  20260723 output/dd_bridge_bounds_seed20260723.csv
```

The decision threshold is the early-to-late gross payoff ratio,
`(1 + premium)/(1 + premium + productivity)`. The completed run contains
10,000 paired trials in each of 180 scenarios. Both bounds agree in 153
scenarios; 27 are sensitive to partial-payment classification.
