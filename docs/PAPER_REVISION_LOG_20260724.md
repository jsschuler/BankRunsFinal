# Paper revision log (2026-07-24)

This log records agreed manuscript changes arising from
`deposits-are-not-options-revision-tasks.md`. It distinguishes changes that can
be made from the existing evidence from claims that require a new experiment.
No item below records a new result unless it is already supported by the
corrected DD output.

## Changes accepted for the manuscript

### 1. Liquidation timescale and policy scope

- State that the reserve ratio represents resources available on the
  sequential-service timescale, rather than the bank's complete
  mark-to-maturity balance sheet.
- Explain that a bank may be solvent at a longer horizon while unable to
  convert assets into immediately serviceable funds.
- Use emergency liquidity facilities, including the BTFP where appropriate, as
  illustrations of liquidity transformation. Do not describe such facilities
  as reproducing the Diamond--Dybvig allocation or eliminating solvency risk.
- Verify and cite all institutional claims before inserting them.

### 2. Formal deposit assumption versus simulated allocation choice

- Preserve the formal model's conditioning on a given deposit contract and
  full deposit in the stochastic withdrawal stage.
- Clarify that the existing DD simulation adds a common ex ante allocation
  search over `deposit = 0, 10, ..., 1000`, with the remainder held outside the
  bank.
- Describe this as a planner-style or common allocation choice, not as
  decentralized heterogeneous individual deposit choice.
- Report bank formation separately from failure. A zero-deposit allocation is
  nonparticipation, not bank failure.
- Do not claim that option value generally sustains participation or that
  agents choose maximum deposits in high-failure cells. The corrected run does
  not support those generalizations.

Existing corrected evidence:

- 105 of 360 cells form a bank and 255 select zero deposits;
- among participating cells, 82 select the maximum deposit and 23 select an
  interior deposit;
- among the seven participating cells with failure rates of at least 10
  percent, selected deposits range from 30 to 1,000, with a median of 820.

### 3. Contracts as institutional givens

- Explain that the theoretical exercise conditions on an offered deposit
  contract in order to isolate the withdrawal mechanism.
- Treat participation and deposit allocation as separate ex ante outcomes in
  the simulation.
- Do not use the present allocation-search results as evidence that the
  contract is generally accepted at the simulated premia: participation is
  105/360, or 29.2 percent, across the corrected grid.

### 4. Shifted CRRA

- Remove language implying that shifted and unshifted CRRA are interchangeable
  when consumption can be zero.
- State explicitly that the shift affects the utility cutoff.
- Either fix the shift at one and identify it as a normalization or introduce a
  general shift parameter. Do not call the shift a simulation calibration axis
  unless the numerical analysis actually varies it.

### 5. Local-information sampling

- Add the bias--variance qualification: larger neighborhoods reduce local
  sampling variance and may improve representativeness, but do not guarantee
  unbiased beliefs when network position and withdrawal behavior are
  correlated.

### 6. Literature and global-games comparison

- Add the relevant empirical run, contract-design, dynamic-run, and information
  aggregation literature after verifying the proposed references.
- Replace the claim that global-games models have "no analogue" to the paper's
  information intervention with the narrower claim that endogenous
  observability and transmission are not usually their principal policy
  margin.

### 7. Gates, batching, and money-market funds

- Distinguish threshold-triggered gates or fees from universal simultaneous
  batching. Threshold policies can create anticipatory incentives around the
  trigger; universal batching removes the within-period sequential
  observational channel.
- Do not claim that batching necessarily reduces bank-failure probability to
  the exogenous shock probability. It removes a propagation mechanism, while
  fundamental and aggregate-liquidity failures may remain.
- Verify the history and details of the 2023 money-market-fund reforms against
  primary regulatory sources before adding them.

## New DD experiment required before further claims

The proposed small-\(\varepsilon\) exercise should be separated into two
experiments:

1. **Theorem-facing fixed-allocation experiment.** Hold the deposit allocation
   fixed, preferably at the prespecified full-deposit allocation, across
   matched parameter values. Run small withdrawal premia
   \(\varepsilon \in \{0, 0.01, 0.02, 0.05, 0.10\}\). Use this experiment to
   study the withdrawal/failure mechanism and convergence toward the
   zero-premium limit.
2. **Participation extension.** Retain the common allocation search and report
   bank formation, selected deposits, welfare, and failure conditional on bank
   formation. Treat this as an ex ante participation exercise, not as the
   numerical validation of the fixed-contract theorem.

The initial fixed-allocation experiment was subsequently implemented and
completed. Its 600 cells and six million holdout realizations are stored in
`output/dd_fixed_small_epsilon_seed20260724.csv`. At that stage, the
allocation-search participation extension had not yet been run; it was later
included in the expanded overnight sweep recorded below.

## Implemented after the expanded overnight sweep (2026-07-25)

- Replaced the preliminary DD results with the completed 49,440-cell
  experiment: 41,600 fixed-contract cells, 6,400 main allocation cells, and
  1,440 targeted utility-shift allocation cells.
- Rewrote the simulation section to separate theorem-facing fixed deposits
  from the ex ante common-allocation and participation exercise.
- Defined default as a contractual shortfall and stated explicitly that exact
  exhaustion after paying all par claims is settlement. At zero premium all
  5,200 fixed cells settle, including certain withdrawal; at certain
  withdrawal every positive-premium cell defaults.
- Replaced pointwise simulation-monotonicity language with the supported
  aggregate and boundary claim and reported the nine material local reversals.
- Reported participation, selected deposits, and high-failure allocations
  without claiming that the option channel generally sustains maximum
  deposits.
- Generalized shifted CRRA to an explicit positive shift `a`, removed the
  shifted/unshifted equivalence claim, and reported the calibrated numerical
  robustness separately from mathematical non-equivalence.
- Added new fixed-contract and allocation figures to the main text and moved
  expanded-grid and utility-shift details, including a third figure and a
  premium table, to the appendix.
- Updated the abstract, introduction, scope discussion, formal-model
  operationalization, conclusion, and computational-design appendix to match
  the new evidence.
- Rebuilt the manuscript successfully with knitr, BibTeX, and pdfLaTeX. The
  compiled PDF has no undefined references or citations.

## Referee-proofing revision (2026-07-25)

- Recast Theorem 1 as a conditional comparative static given an imposed
  equilibrium survival composite. Continuity, strict monotonicity, and
  uniqueness are explicitly assumptions on that map rather than results
  derived from primitive withdrawal hazards.
- Weakened the failure comparative static to weak monotonicity, with
  strictness only under a positive-probability boundary-crossing condition.
  Corrected the implicit-function display so it no longer drops the direct
  derivative of survival with respect to the withdrawal payment.
- Replaced the simulation's claimed Nash/rest-point interpretation with
  irreversible terminal cascade states, matching its actual stopping rule.
- Restricted isotonicity and Tarski to an exact deterministic threshold
  benchmark with fixed bank-state components. The manuscript now states that
  finite Monte Carlo error, partial payments, reserve depletion, and changing
  insurance can prevent that argument from applying to realized simulations.
- Replaced “two equilibria generically exist” with conditional low- and
  high-withdrawal rest points for the analytical benchmark.
- Derived the calibrated bridge threshold as `1/1.25 = 0.80` under binary
  recovery and risk neutrality, and contrasted it with the shifted-log cutoff
  `log(2)/log(2.25) ≈ 0.855`.
- Distinguished neighborhood degree/local sample size from shortcut density,
  clustering, path length, centrality, and general topology.
- Added an explicit empirical-predictions and data-requirements subsection.
- Softened the SVB timing comparison to mechanism fit rather than empirical
  identification.
- Standardized the main terminology: theorem-defined recovery-probability
  cutoff, calibrated bridge threshold, canonical DD panic equilibrium,
  network terminal cascade state, DD contractual default, network vault
  exhaustion, and formal survival probability.
- Consolidated repeated qualifications and reduced the compiled manuscript
  from 59 to 58 pages despite adding the calibration derivation and empirical
  predictions.
- Deliberately left the alternative belief-law robustness exercise unresolved
  for a separate design discussion.
