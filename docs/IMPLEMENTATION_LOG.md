# Implementation log

## 2026-07-23: DD core validation

- Corrected the conditioned-Binomial sampler and removed the economically
  unsupported zero-probability endpoint.
- Reinterpreted withdrawal probability as the prior over total eventual
  withdrawals.
- Added common random numbers across withdrawal-premium comparisons.
- Separated the 1,000-realization allocation search from the independent
  10,000-realization holdout evaluation.
- Completed all 360 final DD jobs. Failure was nondecreasing in the withdrawal
  premium in all 120 matched parameter groups.

## 2026-07-23: Typed decision and bound interfaces

- Replaced enum-controlled model branches with immutable struct types and
  multiple dispatch.
- Added distinct withdrawal-favoring and staying-favoring partial-payment
  bounds.
- Added paired recovery counts so both bounds necessarily consume the same
  underlying trials.

## 2026-07-23: Model-separation correction

The partial-payment bound machinery was initially connected directly to a
subjective network-state payment generator. That generator is useful for the
network model, but it is not the distinct stochastic DD model that maps onto
the bridge theorem. This omission was identified before any research-scale
bound result was claimed.

The required architecture is:

1. `FiniteAgentDDBridgeModel`: a homogeneous, finite-agent stochastic DD model
   with sequential service and paired withdraw/stay counterfactuals;
2. `WithdrawalFavoringBound` and `StayingFavoringBound`: generic
   interpretations applied to the bridge model's paired recovery trials;
3. `NetworkState` and its later activation loop: a separate heterogeneous,
   graph-observation contagion model.

The bridge and network models must have distinct state and action types.
Shared operation names are selected through multiple dispatch. Bound
interpretations never generate economic states or trial draws themselves.

## 2026-07-23: Distinct stochastic DD bridge validation

- Added `FiniteAgentDDBridgeModel`, `DDBridgeState`,
  `DDBridgeWithdrawNow`, and `DDBridgeStay`. None of these types inherit from
  or contain network state.
- For each trial, the model draws other agents' future withdrawals once and
  applies that same draw to both focal-agent counterfactuals.
- Classified each paired payment against the focal deposit and then applied
  both partial-payment bound types.
- Used the bridge-theorem threshold
  `(1 + withdrawal_premium) / (1 + withdrawal_premium + productivity)`,
  which compares binary-recovery expected payoffs.
- Ran 10,000 paired trials for each of 180 parameter scenarios using run seed
  `20260723`.
- The two bounds agree in 153 scenarios: 75 robustly prescribe withdrawal and
  78 robustly prescribe staying. The remaining 27 scenarios are genuinely
  sensitive to the treatment of partial payments.
- Results are stored in
  `output/dd_bridge_bounds_seed20260723.csv`.

## 2026-07-23: Three typed local-information network models

- Added three distinct concrete network model types:
  `ComparativeNetworkModel`, `ThresholdNetworkModel`, and
  `ExplicitUtilityNetworkModel`.
- All three use `run_network_model`. Decision behavior is selected by dispatch,
  not a mode flag.
- Comparative and threshold models classify full recovery at par. The explicit
  utility model evaluates the paired payment amounts directly with shifted CRRA
  utility and applies the late-return multiplier to the value of staying.
- Actual and subjective withdrawal payments are explicitly capped at the
  agent's deposit. The late-return multiplier changes utility, never the bank's
  payment.
- Agents infer withdrawal risk from the fraction of their neighbors already
  withdrawn, subject to a baseline prior. They remain uncertain about
  unobserved and future withdrawals.
- Every activation decision creates a fresh snapshot of the current objective
  vault and withdrawal state.
- The validation uses common graphs, initial shocks, and seeds across model
  types; 100 replications for each of six reserve/shock configurations; 200
  agents; and 200 subjective draws per decision.
- No above-par payment occurs in any of the 1,800 model results.
- All three models agree on the failure outcome in 84.2% of matched scenarios.
  The threshold and explicit-utility models are especially close (overall
  failure rates 0.080 and 0.088). The comparative rule is more sensitive,
  with failure rate 0.238, but has the same qualitative reserve gradient:
  failure falls sharply as reserves rise from 0.20 to 0.40.
- Results are stored in
  `output/network_validation_seed20260723.csv`.

## 2026-07-23: Small-object and large-sparse execution models

- Added `SmallObjectNetworkModel` for transparent object-level debugging.
  Subjective counterfactuals clone a complete state and execute withdrawals
  explicitly.
- Added `LargeSparseNetworkModel` for production runs. It shares the objective
  deposit vector, carries the current vault as a scalar, and represents each
  subjective future as only a sparse vector of withdrawal indices.
- Both execution objects wrap any of the three economic network models and use
  the same `run_network_model` and `subjective_payments` function names.
- Added exact parity tests across comparative, threshold, and explicit-utility
  models with heterogeneous deposits and fixed insurance.
- A focused benchmark with 1,000 agents and 1,000 subjective trials allocated
  17,541,248 bytes for the small-object model and 16,288 bytes for the sparse
  model, a 1,077-fold reduction. Observed runtime was approximately 94 times
  faster for the sparse payment calculation.
- Re-ran the complete 1,800-model validation with
  `LargeSparseNetworkModel`. Its CSV is byte-for-byte identical to the prior
  small-object result (SHA-256
  `976c4b4942dee31987babf0aa0e4a7f72470fee217d2eb3cf62b1603ab456555`).
- The sparse validation copy is
  `output/network_validation_seed20260723_sparse.csv`.

## 2026-07-23: Sparse withdrawal sampling decision

- A subjective trial first draws the required number `k` of additional
  withdrawals and then samples exactly `k` eligible agents without replacement.
- Full permutations of all eligible agents are prohibited in the production
  sampler.
- The objective state maintains a dense vector of currently banking agents and
  an inverse position map. Objective withdrawals update both with swap-delete
  bookkeeping.
- When `k` is small, the sampler selects `k` active ranks directly with an
  implicit partial Fisher-Yates map.
- When `k` exceeds half the eligible population, it samples the smaller
  complement and emits the remaining agents.
- The focal agent is excluded by rank mapping rather than by constructing a
  filtered eligible-agent vector.
- Only the selected agents are shuffled, preserving random withdrawal order
  with work proportional to the output size.
- The first implicit-remapping implementation failed uniqueness and uniformity
  tests. It was replaced before use with Floyd's exact without-replacement
  algorithm plus complement sampling.
- On 1,000 agents, 1,000 trials, and a 0.02 baseline probability, order
  generation allocations fell from 8,601,408 bytes to 1,023,152 bytes
  (8.4-fold reduction), with a focused runtime improvement of approximately
  7.7 times.
- The complete 1,800-model validation was rerun after changing the RNG
  consumption pattern. Failure rates remain similar: comparative `0.237`,
  threshold `0.082`, and explicit utility `0.087`; matched three-model
  agreement is `84.5%`; no payment exceeds par.
- Post-sampler results are stored in
  `output/network_validation_sparse_sampler_seed20260723.csv`.

## 2026-07-23: Typed production parameter layer

- Added deposit specification structs with a shared `generate_deposits`
  interface:
  - `HomogeneousDeposits`;
  - `ClippedLogNormalDeposits`;
  - `ClippedParetoDeposits`.
- Clipped heterogeneous draws are iteratively normalized while retaining hard
  bounds. The heuristic grid uses a target mean of 10, lower bound 1, and upper
  bound 100. LogNormal `sigma` values are `0.5`, `1.0`, and `1.5`; Pareto
  `alpha` values are `1.5`, `2.0`, and `3.0`.
- Added topology specification structs with a shared `generate_graph`
  interface:
  - Watts–Strogatz degrees `6`, `10`, `20` crossed with rewiring probabilities
    `0.05`, `0.15`, `0.30`;
  - Erdős–Rényi expected degrees `6`, `10`, `20`;
  - Barabási–Albert attachment counts `3`, `5`, `10`;
  - complete topology.
- Added insurance specification structs with a shared `resolve_insurance`
  interface:
  - no insurance;
  - fixed absolute caps at 50% and 100% of the target mean;
  - realized-deposit quantiles `0.50`, `0.90`, and `0.98`;
  - adaptive coverage equal to the largest previously withdrawn deposit, with
    zero coverage before withdrawal history exists.
- The grids are explicitly labelled heuristic and can be narrowed before the
  production experiment job grid is frozen.

## 2026-07-23: Production run planning benchmarks

- Measured complete 1,000-agent model runtimes at 200 and 1,000 subjective
  draws across unstressed and locally clustered-shock scenarios.
- Unstressed models take approximately 0.10 seconds at 200 draws and 0.50
  seconds at 1,000 draws.
- Stressed 200-draw models ranged from 0.62 to 8.14 seconds; stressed
  1,000-draw models ranged from 2.61 to 37.22 seconds.
- Adopted a three-second planning mean and six-second contingency mean for
  200-draw full-grid estimates.
- Recorded the staged convergence, coverage, exploratory, and confirmatory plan
  in `docs/NETWORK_RUN_PLAN.md`.
- Confirmed reserve ratios `0.20`, `0.30`, and `0.40`, shock sizes `1` and `10`,
  and both uniformly random and localized-neighborhood shock mechanisms.
- Replaced the proposed uniform exploratory replication stage with a
  reproducible TPE/Bayesian active-learning stage targeting high failure
  entropy, model disagreement, uncertainty, and parameter-space coverage.
- Kept final inference separate: selected configurations receive independent
  fixed-seed holdout replications after the adaptive design is frozen.

## 2026-07-23: Resumable staged experiment runner

- Added typed `ConvergenceStage`, `CoverageStage`, `AdaptiveStage`, and
  `ConfirmatoryStage` objects.
- Added typed random and localized shock-location specifications and typed
  economic-decision specifications.
- Stable job IDs are generated before execution. Graphs, deposits, shocks, and
  model streams are matched across decision models.
- Subjective draw count is excluded from convergence scenario/model seeds, so
  100/200/500/1,000-draw comparisons use the same underlying scenarios. Draw
  count remains part of the unique job ID.
- Workers return complete records; the master writes atomic CSV chunks.
  Restarted stages scan chunk job IDs and skip completed work.
- Run manifests contain a SHA-256 fingerprint of the package source, staged
  runner, project, and manifest. Resume is rejected when the current source
  does not match, preventing mixed-version result chunks.
- Incomplete stages cannot be frozen. Coverage requires frozen convergence,
  and the selected draw depth is stored in the run manifest.
- Added deterministic merging, status reporting, adaptive scoring, frozen
  adaptive selections, and separate confirmatory seeds.
- The adaptive discrete-grid score combines beta-binomial failure entropy,
  disagreement across decision models, posterior uncertainty, and a runtime
  penalty. Off-grid TPE proposals are reserved for the next extension.
- A limited smoke run verified initialization, atomic output, resume scanning,
  merging, status, and incomplete-freeze rejection without launching the
  production grid.

## 2026-07-23: Stage-one external launch prepared

- Production run directory: `runs/network_20260723`
- Root run seed: `20260723`
- Stage: convergence
- Jobs: 17,280
- Julia processes: 16 total, normally 15 workers and one master
- Estimated wall time: 2–6 hours; allow up to 8 hours for thermal throttling or
  an unusually large share of near-boundary activation paths.
- Persistent shell log:
  `runs/network_20260723/convergence-run.log`
- Exact launch, monitoring, resume, merge, and freeze commands are recorded in
  `docs/NETWORK_RUN_PLAN.md`.

## 2026-07-23: Subjective-draw convergence decision

- Merged all 17,280 stage-one jobs and compared 100-, 200-, and 500-draw runs
  with their paired 1,000-draw references. The comparison covered 4,320 paired
  runs and 144 structural-scenario/decision-model cells, with 30 replications
  per cell.
- Selected **500 subjective draws** for the coverage, adaptive, and
  confirmatory stages. This is the smallest tested depth with failure rates
  identical to the 1,000-draw reference in every one of the 144 cells.
- At 100 and 200 draws, one cell at each depth differed from the reference by
  one failure in 30 replications (3.33 percentage points). Run-level failure
  disagreement was 1/4,320 at both depths. At 500 draws, two paired run
  outcomes differed but offset within their cells, leaving every cell-level
  failure rate unchanged.
- For total and endogenous withdrawals, respectively, 500 draws had 93.84%
  exact run-level agreement, mean absolute error 1.181 agents, 95th-percentile
  absolute error 3 agents, and 99th-percentile absolute error 20 agents.
  Initial withdrawals are fixed within each pair, so the total- and
  endogenous-withdrawal differences are identical.
- The difficult comparative-decision cells converged more slowly than the
  other models. Relative to 1,000 draws, the comparative model's overall mean
  total withdrawals were 11.6% lower at 100 draws, 9.9% lower at 200 draws,
  and 3.9% lower at 500 draws. The largest cell-level mean difference fell
  from 75.1 agents at 100 draws and 72.5 at 200 draws to 35.4 at 500 draws;
  that reference cell had a replication standard deviation of 174.6 agents.
- The selection prioritizes stable scenario/model conclusions over the lower
  runtime of 100 or 200 draws. The run manifest must be updated with
  `set-draws runs/network_20260723 500` only after the convergence stage is
  frozen.

## 2026-07-23: Intermediate handoff before production stages

- Verified at sign-off that convergence results are merged but **not yet
  frozen**. The run manifest still contains its initialization default,
  `selected_decision_draws = 200`; coverage has not started and there is no
  coverage output directory or log yet.
- Before starting coverage, run:

  ```sh
  julia --project=. scripts/network_experiment.jl \
    freeze convergence runs/network_20260723

  julia --project=. scripts/network_experiment.jl \
    set-draws runs/network_20260723 500
  ```

- Then launch the resumable 141,120-job coverage audit:

  ```sh
  nohup julia --project=. scripts/network_experiment.jl \
    run coverage runs/network_20260723 \
    --workers 16 \
    > runs/network_20260723/coverage-run.log 2>&1 &
  echo $!
  ```

- Monitor with `tail -f runs/network_20260723/coverage-run.log` or
  `julia --project=. scripts/network_experiment.jl status
  runs/network_20260723`. At 500 draws, the current estimate is 25–50 hours;
  the Thursday-evening-to-Sunday availability window is probably sufficient
  but retains runtime-tail risk.
- If the machine must stop before completion, rerun the same `nohup` coverage
  command later. Existing atomic chunks will be detected and their job IDs
  skipped. Do not remove partial coverage chunks.
- After all coverage jobs finish, merge, inspect, and freeze coverage before
  adaptive selection. Do not freeze an incomplete stage:

  ```sh
  julia --project=. scripts/network_experiment.jl \
    merge coverage runs/network_20260723
  julia --project=. scripts/network_experiment.jl \
    freeze coverage runs/network_20260723
  ```

- Do not edit package source, `scripts/network_experiment.jl`,
  `Project.toml`, or `Manifest.toml` during this run: their fingerprint must
  remain equal to the value stored in the run manifest. Documentation edits
  do not affect the fingerprint.
- The adaptive and confirmatory stages remain unstarted and are not expected
  to fit in the current machine-availability window.

This section records the state at that intermediate checkpoint and is
superseded by the 2026-07-24 entry below.

## 2026-07-23: Matched coverage diagnostic

- Completed and merged all 141,120 coverage jobs, comprising 47,040 complete
  matched scenario/replication groups with all three decision models and
  identical scenario seeds.
- Added `scripts/diagnose_coverage_matches.jl`. It validates match completeness
  and scenario invariants, writes pairwise comparative-model contrasts,
  summarizes deposit/insurance strata, and reports near-depletion outcomes.
- The comparative model survived while threshold or explicit utility failed in
  3,985 pairwise matches. Every one of these reversals used heterogeneous
  deposits; none occurred with homogeneous deposits.
- In 2,177 of those 3,985 reversals (54.63%), the comparative model made more
  withdrawals yet retained more vault value. This directly confirms that the
  identities and claim sizes of withdrawing agents, rather than withdrawal
  counts alone, explain a material portion of the failure-order reversal.
- The exact failure boundary is also material. `failed` is defined as
  `final_vault <= 0`. The comparative model recorded zero failures in all
  40,320 heterogeneous-deposit runs, but 1,731 finished with less than one
  unit in the vault, 4,157 finished with less than 20 units, and the minimum
  residual was `0.000352338`.
- The zero comparative failure rate for heterogeneous deposits should
  therefore not be read as absence of severe distress. Subsequent reporting
  should show exact exhaustion and near-depletion outcomes together. Coverage
  remains unfrozen pending a decision on whether the production failure
  estimand should retain exact exhaustion or add a preregistered distress
  threshold.
- Diagnostic artifacts are:
  - `runs/network_20260723/coverage/matched_diagnostic_report.md`;
  - `runs/network_20260723/coverage/matched_diagnostic_pairs.csv`;
  - `runs/network_20260723/coverage/matched_diagnostic_strata.csv`;
  - `runs/network_20260723/coverage/matched_diagnostic_near_depletion.csv`.

## 2026-07-23: Initial-condition knife-edge design

- Clarified the primary network estimand: near exhaustion is expected under
  the architecture; the main interest is knife-edge sensitivity to the
  identities and locations of initially withdrawing agents.
- The coverage replications cannot isolate that estimand because their
  scenario seed jointly regenerates deposits, the graph, and the initial
  shock. Coverage remains useful for locating candidate cells, but
  replication-level outcome variation cannot be attributed to initial
  conditions alone.
- Added `scripts/initial_condition_sensitivity.jl`, a standalone experiment
  that leaves the initialized production run fingerprint unchanged.
- The design uses separate stable seed coordinates:
  - coordinate 20 fixes the graph and deposits for a structural realization;
  - coordinate 21 varies only initial-shock membership and location;
  - coordinate 22 supplies a model stream shared across the three decision
    models for that shock trial.
- Candidate cells are ranked from coverage using within-model mixed outcomes,
  posterior failure entropy, cross-model disagreement, and withdrawal-count
  dispersion. For each selected cell, multiple fixed structural realizations
  are crossed with multiple initial-shock trials.
- The knife-edge outcome is a failure flip within a fixed
  structure/decision-model cell when only shock membership changes. The report
  also records the within-cell range and standard deviation of total
  withdrawals.
- Shock trials run in parallel with Julia threads. The proposed initial run is:

  ```sh
  julia -t 16 --project=. scripts/initial_condition_sensitivity.jl \
    run runs/network_20260723 \
    --cells 20 \
    --structures 3 \
    --shocks 50
  ```

  This contains 9,000 model runs. Based on a deliberately slow validation cell
  (roughly 6–15 seconds per model), allow approximately 2–6 hours on 16
  threads. The runner prints progress every 100 models.
- A six-model bounded validation confirmed that the graph/deposit seed is fixed
  across shock trials, shock membership changes with the shock seed, and all
  three decision models receive the same initial agents and model seed within
  each trial. The two validation shocks both failed in all models; this is a
  plumbing validation, not an empirical knife-edge conclusion.
- Validation artifacts are in
  `runs/network_20260723/initial_conditions/validation_results.csv` and its
  `_cells.csv` and `_report.md` companions.

## 2026-07-24: Adaptive completion and learned confirmatory selection

- Froze coverage with all 141,120 jobs after the matched diagnostic and
  fixed-structure initial-condition review.
- Selected 100 high-entropy coverage cells and completed adaptive batch 1:
  150,000 unique jobs, 500 replications per decision model in every selected
  structural cell, using 500 subjective draws.
- The merged adaptive output passed integrity checks: all job IDs are unique,
  each structural cell has exactly 1,500 rows, outcome and timing fields are
  finite and in range, and `above_par_payments` sums to zero.
- Replaced the original confirmatory workflow, which merely copied the
  pre-adaptive selection, with outcome-informed selection from the completed
  adaptive batch.
- For every structural-cell/decision-model pair, the learned selector computes
  a beta-binomial posterior failure probability, Bernoulli entropy, posterior
  standard deviation, and mean runtime. Structural-cell scores combine mean
  entropy, cross-model probability disagreement, uncertainty, and a logarithmic
  runtime penalty.
- Added a deterministic greedy diversity bonus over deposit family, topology
  family, insurance regime, reserve ratio, shock size, and shock location.
  This maintains design representation without allowing diversity to replace
  the primary boundary/disagreement objective.
- Added `select-confirmatory RUN_DIR --cells N`. `freeze-selection` now freezes
  that learned manifest rather than copying `adaptive/selection.csv`.
- Added a gated `adopt-selection-learning` migration for the existing run. It
  is permitted only after adaptive batch 1 is frozen and before confirmatory
  selection is frozen. The migration records the previous and current source
  fingerprints in `runs/network_20260723/SELECTION_LEARNING_MIGRATION`.
- Generated and froze an 80-cell confirmatory selection. Its score and
  selection SHA-256 hashes are recorded in
  `confirmatory/SELECTION_FROZEN`. The selected cells span all categories
  available in the adaptive pool, all three reserve levels, both shock sizes,
  and both shock-location mechanisms.
- The selected reserve distribution is deliberately boundary-focused:
  68 cells at 0.20, 11 at 0.30, and one at 0.40. This selection is suitable for
  confirmation but not for standalone monotonicity claims.
- Confirmatory execution contains 96,000 independent jobs:
  80 complete structural configurations × 3 decision models × 400
  replications. Adaptive timings imply 49.6 worker-hours and approximately
  3.5–5 wall-clock hours with 16 processes.
- Added tests for adaptive-result scoring, ranking, replication accounting,
  deterministic selection ranks, and diversity behavior. The complete package
  test suite passes.
- Specified a separate outcome-independent monotonicity stage for after
  confirmation. The proposed 39,600-job design uses six prespecified
  representative structures, matched seeds, 200 replications, and one-factor
  paths in reserves, fixed insurance coverage, and shock size. This prevents
  adaptive boundary selection from being used as evidence for global
  comparative statics.

## 2026-07-24: Prespecified monotonicity runner

- Added a resumable `monotonicity` stage containing six representative
  structures, 11 settings, three decision models, and 200 replications:
  39,600 jobs.
- Counted the common reserve `0.30`, fixed-insurance `5.0`, shock-size `5`
  baseline once. The other settings vary exactly one factor along the paths
  recorded in the design plan.
- Matched scenario and model seeds across all settings within each
  structure/replication pair while retaining a unique job ID for every
  setting and decision model.
- Added `prepare-monotonicity` and `freeze-monotonicity-design`. The freeze
  marker hashes both the 66-row design and the three directional hypotheses,
  and execution verifies those hashes before generating outcomes.
- Added `adopt-monotonicity` to record the source-fingerprint migration only
  after confirmatory results are frozen and before monotonicity execution.
- Added monotonicity coverage to runner status, documentation, and the test
  suite.
- After explicit approval, the complete package test suite passed. The new
  monotonicity test set passed all 24 assertions covering the 39,600-job
  design, unique identifiers, six-by-eleven balance, three hypotheses, and
  matched scenario/model seeds across settings.
- An isolated temporary-run smoke test passed source-fingerprint migration,
  design preparation, design/hypothesis freezing, exact job accounting,
  post-freeze hash-tamper rejection, restoration, and a real one-job
  monotonicity execution that wrote a valid resumable chunk.
- No production monotonicity files or migration markers were created during
  testing. At sign-out, the production continuation begins with
  `adopt-monotonicity runs/network_20260723`, followed by
  `prepare-monotonicity` and `freeze-monotonicity-design`.

## 2026-07-24: Fixed-allocation small-premium DD experiment

- Corrected the DD default event. Exact exhaustion after paying a promised
  claim in full is settlement, not default. Default now requires at least one
  early claimant to receive less than the contractual early payment.
- Added realization-level accounting for the initial withdrawal draw, executed
  initial withdrawals, endogenous withdrawals, post-default claims, total
  withdrawals, claimant shortfalls, and realized utility.
- Added `DDFixedResult` and `run_dd_fixed_job` so a prespecified deposit can be
  evaluated independently of the common allocation search.
- Added endpoint regression tests. With full deposits, certain withdrawals,
  and a zero premium, all claims are paid at par and failure is zero. A
  positive premium under the same conditions produces a payment shortfall and
  failure. The complete package test suite passes.
- Ran the fixed full-deposit design with 50 agents, 100 subjective decision
  draws, 10,000 holdout realizations, withdrawal premia
  `{0, 0.01, 0.02, 0.05, 0.10}`, productivities `{0.50, 0.55, 0.60}`,
  withdrawal probabilities `0.05:0.05:1.0`, and risk-aversion values
  `{1, 0}`.
- The resulting 600 cells contain six million holdout realizations. All 600 job
  indices are unique, and model seeds are matched across premia within each
  `(rho, productivity, withdrawal_probability)` group.
- No zero-premium realization defaults. At withdrawal probability one, all
  zero-premium cells settle at par, while all positive-premium cells default.
- Average failure rises with the premium. Across productivities and withdrawal
  probabilities it is `0.099`, `0.102`, `0.195`, and `0.286` for log utility
  at premia `0.01`, `0.02`, `0.05`, and `0.10`; the corresponding
  risk-neutral values are `0.055`, `0.098`, `0.164`, and `0.271`.
- The 50-percent failure boundary moves from withdrawal probability
  approximately `0.95--1.00` at a one-percent premium to approximately
  `0.75--0.80` at a ten-percent premium. There are no matched premium
  monotonicity violations larger than two percentage points.
- Results are stored in
  `output/dd_fixed_small_epsilon_seed20260724.csv` with SHA-256
  `424df75c9ca960daa98c4c7af2ef68f596819bed4275d9394801e13bde100cc7`.

## 2026-07-24: Expanded overnight DD sweep

- Generalized shifted CRRA to an explicit positive `utility_shift` parameter.
  The shift is stored in every DD job and result. Common random numbers are
  preserved across both premium and shift comparisons.
- Added tests for the shift axis, including its effect on utility at zero and
  seed matching across shifts. The complete package test suite passes.
- Added a resumable, atomic-chunk overnight runner with immutable TOML designs,
  SHA-256 design fingerprints, completed-job scanning, and deterministic final
  merges.
- Prespecified three separately labelled panels:
  - `allocation_main`: 6,400 jobs, shift fixed at one, four risk-aversion
    values, eight premia, four productivities, and withdrawal probability in
    increments of 0.02;
  - `allocation_shift`: 1,440 jobs targeting nonlinear utility at shifts
    `0.1`, `10`, and `100`, four selected premia, two productivities, and
    withdrawal probability in increments of 0.05;
  - `fixed_sensitivity`: 41,600 jobs using full deposits, all thirteen
    nonredundant `(rho, shift)` specifications, eight premia, four
    productivities, and withdrawal probability in increments of 0.01.
- Risk-neutral utility is run only at shift one because the shift is an
  additive constant under linear utility and cannot alter choices.
- Allocation panels use 1,000 search realizations for each of 101 candidate
  deposits and 10,000 independent holdout realizations. The fixed panel uses
  10,000 holdout realizations.
- A temporary-run smoke test passed design verification, atomic chunk writing,
  completed-job scanning, repeat initialization, and deterministic merging.
- The run directory is `runs/dd_overnight_20260724`. Execution begins with the
  main allocation panel, followed by the targeted shift allocation panel and
  the broad fixed-contract panel.

## 2026-07-25: Expanded DD analysis

- Completed and integrity-checked all 49,440 overnight parameter cells:
  6,400 main allocation cells, 1,440 targeted shift-allocation cells, and
  41,600 fixed full-deposit cells. All panels have unique job identifiers.
- Added the reproducible R analysis
  `analysis/dd_overnight_analysis.R`, with derived tables, three figures, and a
  concise Markdown report in `analysis/dd_overnight_results`.
- In the fixed experiment, all 5,200 zero-premium cells settle without
  default. At withdrawal probability one, zero-premium claims settle at par
  while every positive-premium cell defaults.
- Mean fixed-allocation failure rises from 0.060 at a 0.5-percent premium to
  0.677 at a 50-percent premium. The median 50-percent-failure boundary moves
  from withdrawal probability 0.95 to 0.35 over the same range.
- Productivity has the expected stabilizing effect: none of 10,400 matched
  paths has a failure increase greater than one percentage point, and the mean
  adjacent productivity-step change is -0.0314.
- Premium monotonicity is strong in aggregate but not literally pointwise:
  nine of 5,200 matched paths have a failure-rate drop greater than one
  percentage point. These reversals occur near the high-withdrawal boundary
  and mainly at utility shift 100.
- In the allocation search, participation falls from 0.979 at zero premium to
  0.330 at a 50-percent premium; mean selected deposits fall from 960.4 to
  317.1. Zero-premium nonparticipation is concentrated at certain withdrawal,
  where par withdrawal and outside storage are payoff-equivalent.
- High-failure participating cells do not generally select full deposits.
  Across 142 cells with failure of at least 10 percent, deposits range from 10
  to 1,000; only risk-neutral cells ever select the full deposit in this
  subset.
- The CRRA shift is mathematically non-equivalent but numerically modest in the
  targeted allocation comparison. Participation is identical across shifts;
  exact deposit agreement is at least 85 percent in every rho-premium group;
  and the largest within-cell deposit difference is 100.

## 2026-08-12: Alternative belief-law robustness check

- Motivation: the belief-model qualification paragraph in `paper.Rnw` asserts
  the truncated-Geometric belief used by the theorem-facing analytical model
  is "a tractable baseline, not a claim of uniqueness," but that claim was
  never checked against the production network simulation, which instead
  uses an unrelated, ad hoc point-estimate mechanism
  (`local_withdrawal_probability`: `max(baseline, local_fraction)` plugged
  into a Binomial). This is a real internal-consistency gap between the
  theorem's belief law and the simulation's belief law, not merely a
  hypothetical robustness concern.
- Added `src/network.jl` support for pluggable belief laws via ordinary
  multiple dispatch, no conditional branching on belief type anywhere:
  `abstract type BeliefModel end`, `PointEstimateBelief` (wraps the existing
  mechanism unchanged), and `TruncatedGeometricBelief` (reproduces the
  paper's own eqs.~\ref{eq:tau}--\ref{eq:belief} exactly: `W ~ Geometric(p0)
  | W >= round(K * local_rate)`, sampled exactly via the Geometric's
  memorylessness as `round(K * local_rate) + Geometric(p0)`, then converted
  to a future-withdrawal count among currently eligible agents). Dispatch
  function is `draw_future_withdrawal_count(rng, belief, model, state,
  focal_agent, eligible_count)`. `NetworkScenario` gained an optional
  `belief` field defaulting to `PointEstimateBelief()`, so every existing
  call site is unchanged; full 213-test suite passed unmodified before 9 new
  belief-law tests were added (222 total).
- An initial attempt used a Beta-Binomial posterior-predictive belief
  (a genuine Bayesian prior/posterior over the withdrawal probability) as
  the alternative. This was the wrong comparison: neither the paper's
  theorem nor the simulation has any notion of a prior over a probability
  parameter anywhere; introducing one manufactures a new mechanism rather
  than testing an existing one. Replaced with `TruncatedGeometricBelief`,
  which uses only the paper's own already-stated belief law.
- First attempt at the comparison reused `baseline_withdrawal_probability =
  0.02` (tuned for the point-estimate mechanism's Binomial, whose mean
  scales as `n * p`) as the Geometric's `p0`. Since `Geometric(p0)`'s mean
  is `(1-p0)/p0`, independent of population size, this produced a
  population-invariant mean excess-belief of 49 withdrawals against a
  200-agent network -- every one of 120 scenarios failed deterministically
  under every decision rule. Corrected to `p0 = 0.1`, the value the paper's
  own analytical section actually states for this belief law.
- `scripts/run_belief_robustness.jl` (new) reruns the existing
  common-scenario validation design (Watts--Strogatz(200,10,0.10), reserve
  ratios 0.20/0.30/0.40, initial withdrawal counts 1 and 3, all three
  decision rules) under both belief laws at matched seeds. Result, at 100
  replications per cell (600 matched scenario-rule pairs per belief law)
  and confirmed reproducible across two independent top-level seeds
  (20260812 and 20260813) with non-overlapping 95% Wilson intervals:
  - The reserve-ratio failure gradient is monotonically decreasing under
    both belief laws (point estimate: ~44% / ~5-6% / ~0%; truncated
    geometric: ~81-85% / ~41% / ~33-34%, at r=0.20/0.30/0.40). This
    comparative static is robust to belief-law choice.
  - Cross-decision-rule agreement is not: all three rules agree on
    72.5-72.7% of scenarios under the point-estimate belief (roughly in
    line with the paper's already-reported common-scenario validation
    figures), but only 16.0-20.0% under the truncated-Geometric belief the
    theorem actually uses.
  - The collapse is concentrated in the `comparative` (`RelativeSafety`)
    rule, whose failure rate rises from ~34.6% under the point estimate to
    100.0% [99.4, 100.0] under the truncated Geometric in both seeds --
    effectively deterministic saturation, not noise. `threshold` and
    `explicit_utility` shift less (7.2%->16-20% and 7.5-7.8%->39.5-40.3%).
    This sharpens a pattern the paper already reports elsewhere (the
    comparative rule is the most sensitive of the three) rather than
    introducing a new one.
  - Matched agreement between the two belief laws on the same
    scenario/rule pair is 63.3-64.3% [61-67%] -- well below the >95%
    agreement figures reported for cross-decision-rule comparisons under a
    single belief law.
- Conclusion: the paper's "mechanism robustness across three decision
  rules" claim holds under the point-estimate belief actually implemented,
  but does not hold under the belief law the theorem itself uses. The
  reserve-ratio comparative static appears robust to this choice; the
  cross-rule agreement claim does not. Not yet reflected in the manuscript
  text -- open decision on how (or whether) to qualify the relevant claims
  in `paper.Rnw`.
- Code and tests are in place and committed-ready
  (`src/network.jl`, `src/BankRunsFinal.jl`,
  `scripts/run_belief_robustness.jl`, `test/runtests.jl`); raw output is
  `output/belief_robustness_seed20260812.csv` and
  `output/belief_robustness_seed20260813.csv` (gitignored, reproducible via
  `julia --project=. scripts/run_belief_robustness.jl <seed> <path>`).
