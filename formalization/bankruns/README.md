# Lean formalization of "Deposits Are Not Options"

A Lean 4 / Mathlib formalization of the formal mathematical results in
`paper_revision/paper.tex` (Schuler, *Deposits Are Not Options: Contract Artifacts,
Equilibrium Selection, and Network Contagion in Bank Run Models*).

Build with `lake build` (Lean toolchain pinned to `leanprover/lean4:v4.33.1`, Mathlib
pinned to the same tag in `lakefile.toml`). Every theorem below is proved with **no
`sorry`s and no custom axioms** — `#print axioms` on any of them reports only the three
standard Lean axioms (`propext`, `Classical.choice`, `Quot.sound`).

## What is proved, file by file

- **`Bankruns/Phi.lean`** — Proposition 1 (`prop:upslope`) / Lemma `lem:phi`: the shifted-CRRA
  withdrawal threshold `Φ_shift(c1, c2(c1), ρ)` is strictly increasing in `c1` along the
  Diamond–Dybvig resource constraint, for every risk-aversion parameter `ρ > 0` (both the
  `ρ ≠ 1` and log-utility `ρ = 1` cases). Proved via the exact quotient-rule / "α²"
  sign argument in Appendix A, using `HasDerivAt` and `strictMonoOn_of_deriv_pos`. Also
  proves **regularity condition (R2)**: `Φ(c1,c2,ρ) < 1` whenever `0 < c1 < c2`, and
  `Φ(c1,c2,ρ) > 0` whenever `c1,c2 > 0` — asserted but not proved in the paper ("guaranteed
  by the resource constraint" — Section III).

- **`Bankruns/Bridge.lean`** — Theorem 2 (the Bridge Theorem, `thm:bridge`) and Corollary 1
  (`cor:approx`): as `c1 → 1⁺` (`ε → 0⁺`), `Φ_shift` converges to the bridge threshold
  `p*(ρ, R)`; `p*` is continuous at `ρ = 1` (proved via Mathlib's L'Hôpital's rule,
  `HasDerivAt.lhopital_zero_nhdsNE`); and the first-order slope `M(ρ, R, π)` is strictly
  positive. Also proves: `p*(ρ,R) ∈ (0,1)` is a proper probability (the paper's closing
  remark to Appendix B); the boundary-case claim from Section V ("Generalization to risky
  withdrawal") that certain full recovery from staying (`p_S = 1`) always implies staying
  when `R > 1`; and the pure-algebra equivalence between the utility-consistent comparison
  `\eqref{eq:generalbridge}` and the rearranged withdrawal condition `\eqref{eq:generalcond}`.

- **`Bankruns/PartialPayout.lean`** — Remark `rem:partialpayout`: the finite-`K`
  partial-payment correction to the withdrawal threshold is bounded by `Φ_shift/K < 1/K`,
  an `O(1/K)` perturbation.

- **`Bankruns/ComparativeStatics.lean`** — Existence/uniqueness of the rational-expectations
  threshold `D*` under (R1)–(R2) (an intermediate-value argument), and Theorem 1
  (`thm:main`), BOTH clauses: `D*` is strictly increasing in `c1`, and the failure
  probability `P(τ<T)` is monotone in `c1` (weak clause) — with a further theorem giving
  the paper's STRICT clause ("it is strictly increasing when raising `c1` moves a
  positive-probability set of coupled paths across the failure boundary") as a sufficient
  condition combining `D*`'s always-strict increase with strict monotonicity of the
  failure probability in the threshold. The equilibrium survival composite `S̄` is left
  **abstract** here, satisfying exactly (R1)–(R2) and the antitonicity `JumpProcess.lean`
  establishes concretely — matching the paper's own framing of Theorem 1 as *conditional*
  on those regularity conditions. The `D*`-monotonicity argument is calculus-free: an
  elementary order-theoretic sandwich, strictly more general than the paper's
  implicit-function-theorem sketch (no differentiability of `S̄` is needed, only
  monotonicity).

- **`Bankruns/JumpProcess.lean`** — Lemma `lem:jump` (Channel 3, "the jump-size effect"),
  BOTH clauses, proved from scratch on an explicit finite sequential-service jump process:
  two economies with payments `c1 ≤ c1'`, run on the *same* realization (shock pattern and
  processing order) and the *same* fixed withdrawal threshold, are coupled to show the
  larger-payment pool is pathwise dominated at every time step, hence its failure event is
  a pointwise superset, hence (for *any* `PMF` over realizations, not just i.i.d./uniform
  ones) its failure probability is weakly higher (`Fails_probability_mono`) — and, when a
  positive-probability set of realizations survives under `c1` but fails under `c1' > c1`,
  STRICTLY higher (`Fails_probability_strict_mono`, proved via a from-scratch disjoint-set
  additivity lemma for `PMF.toOuterMeasure`).

- **`Bankruns/Tarski.lean`** — Remark `rem:partialconn` (Knaster–Tarski application):
  instantiates Mathlib's existing Knaster–Tarski fixed-point theorem
  (`Mathlib.Order.FixedPoints`, `OrderHom.lfp`/`OrderHom.gfp`) on the finite lattice of
  withdrawal configurations `Fin K → Bool`, and shows the paper's two boundary conditions
  force the least and greatest fixed points to be the all-stay and all-withdraw
  configurations respectively, hence distinct low- and high-withdrawal rest points.

## Honest scope notes

- **Theorem 1 / `thm:main`** is formalized exactly as the paper states it: *conditional* on
  (R1)–(R2) and on the jump-size antitonicity. `ComparativeStatics.lean` does not derive a
  survival map from primitive withdrawal hazards for general `K`; `JumpProcess.lean`
  supplies one concrete, fully-proved instance of the needed antitonicity (not a derivation
  of the general survival composite `S̄` itself, which the paper also does not give in
  closed form).
- **Lemma `lem:jump`** is proved for an explicit, minimal finite-agent model (sequential
  processing, a fixed threshold rule, single-shock-or-not per step) that captures exactly
  the coupling argument in Appendix A. It does not encode the network model's local-belief
  Monte Carlo machinery (`Bankruns.jl`'s belief updating, insurance, topology, etc.) — that
  machinery is simulation code, not a theorem statement in the paper.
- **Monte Carlo results** (the 49,440-cell / 39,600-run / etc. simulation numbers reported
  throughout the paper) are empirical outputs of the Julia code in `../../src` and `../../scripts`,
  not theorems, and are outside the scope of a Lean formalization.
- **Not formalized**: the adaptive-stress-test framing, the belief-model qualification
  discussion, and other purely narrative/interpretive content, which are not mathematical
  claims to verify.
