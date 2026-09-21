/-
Formalization of the rational-expectations-equilibrium existence/uniqueness result,
Lemma `lem:dstar`, and Theorem `thm:main` (Section III, "Diamond-Dybvig Stochastic Process
Model"), of Schuler, "Deposits Are Not Options".

The equilibrium survival composite `S̄(d; c1)` and the induced failure probability
`P(τ<T)` are left ABSTRACT here, satisfying exactly the regularity conditions (R1)-(R2)
and the "jump-size effect" antitonicity that the paper's Lemma `lem:jump` establishes for
a concrete finite-agent process (formalized separately in `JumpProcess.lean`). This file
proves:

1. Existence and uniqueness of the rational-expectations threshold `D*` under (R1)-(R2)
   (an intermediate-value argument).
2. Lemma `lem:dstar`: `D*` is strictly increasing in `c1`, via a direct order-theoretic
   sandwich argument. This argument is CALCULUS-FREE: it replaces the paper's
   implicit-function-theorem sketch (which implicitly assumes differentiability of the
   survival map) with an elementary monotonicity argument that needs only monotonicity,
   not differentiability, of `S̄`. It is therefore a strictly more general route to the
   same conclusion.
3. Theorem `thm:main`, part (b): the failure probability `P(τ<T)`, viewed as a function of
   `(D*, c1)` that is monotone in each argument (weakly increasing in the threshold, and
   weakly increasing in `c1` via the jump-size effect), is monotone in `c1` once composed
   with the equilibrium threshold map `c1 ↦ D*(c1)`.
-/
import Mathlib

open Set

noncomputable section

namespace Bankruns

/-- Existence and uniqueness of the rational-expectations equilibrium threshold `D*`
under (R1): `S̄(·; c1)` is continuous and strictly increasing on `[0, U]`, running from
`0` to `1`, and the target `Φ_shift(c1) ∈ (0,1)` (part of (R2)). This is the existence
statement preceding Theorem `thm:main` in the paper ("a solution to (fp) exists and is
unique"). -/
theorem exists_unique_equilibrium_threshold {Sbar : ℝ → ℝ} {U t : ℝ} (hU : 0 < U)
    (hcont : ContinuousOn Sbar (Icc 0 U)) (hmono : StrictMonoOn Sbar (Icc 0 U))
    (hS0 : Sbar 0 = 0) (hSU : Sbar U = 1) (ht : t ∈ Ioo (0:ℝ) 1) :
    ∃! d, d ∈ Icc (0:ℝ) U ∧ Sbar d = t := by
  have hsub : Icc (Sbar 0) (Sbar U) ⊆ Sbar '' Icc 0 U :=
    intermediate_value_Icc hU.le hcont
  rw [hS0, hSU] at hsub
  obtain ⟨d, hd_mem, hd_eq⟩ := hsub (Ioo_subset_Icc_self ht)
  refine ⟨d, ⟨hd_mem, hd_eq⟩, ?_⟩
  rintro d' ⟨hd'_mem, hd'_eq⟩
  exact hmono.injOn hd'_mem hd_mem (by rw [hd'_eq, hd_eq])

/-- **Lemma `lem:dstar`** (order-theoretic version): let `S̄` be the equilibrium survival
composite, `Φ` the withdrawal threshold as a function of `c1`. If `D*, D*'` are
equilibrium thresholds at `c1 < c1'` (i.e. `S̄(D*, c1) = Φ(c1)` and
`S̄(D*', c1') = Φ(c1')`), `S̄(·, c1')` is monotone (regularity condition (R1)), `S̄(x, c1') ≤
S̄(x, c1)` for every pool level `x` (the "jump-size effect": raising `c1` weakly lowers
survival at any fixed pool, Lemma `lem:jump`), and `Φ(c1) < Φ(c1')` (Lemma `lem:phi`,
Proposition 1), then `D* < D*'`.

This is calculus-free: unlike the paper's implicit-function-theorem sketch, it needs only
monotonicity, not differentiability, of `S̄`. -/
theorem dstar_strictMono {Sbar : ℝ → ℝ → ℝ} {Phi : ℝ → ℝ} {c1 c1' d d' : ℝ}
    (hfp : Sbar d c1 = Phi c1) (hfp' : Sbar d' c1' = Phi c1')
    (hmono : Monotone (fun x => Sbar x c1'))
    (hanti : ∀ x, Sbar x c1' ≤ Sbar x c1)
    (hPhi_lt : Phi c1 < Phi c1') :
    d < d' := by
  by_contra h
  rw [not_lt] at h
  have h1 : Sbar d' c1' ≤ Sbar d c1' := hmono h
  have h2 : Sbar d c1' ≤ Sbar d c1 := hanti d
  have : Phi c1' ≤ Phi c1 := by
    calc Phi c1' = Sbar d' c1' := hfp'.symm
      _ ≤ Sbar d c1' := h1
      _ ≤ Sbar d c1 := h2
      _ = Phi c1 := hfp
  linarith

/-- **Theorem `thm:main`**, part (b) (composition form): if the failure probability
`Pfail(D*, c1)` is monotone in the equilibrium threshold `D*` (a larger withdrawal region
weakly increases failure) and monotone in `c1` for fixed `D*` (the jump-size effect,
Lemma `lem:jump`), and the equilibrium threshold map `c1 ↦ Dstar c1` is monotone (as given
by `dstar_strictMono` together with existence/uniqueness), then the composite failure
probability `c1 ↦ Pfail(Dstar c1, c1)` is monotone in `c1`. -/
theorem Pfail_comp_mono {Pfail : ℝ → ℝ → ℝ} {Dstar : ℝ → ℝ}
    (hDstar_mono : Monotone Dstar)
    (hPfail_mono1 : ∀ c1, Monotone (fun d => Pfail d c1))
    (hPfail_mono2 : ∀ d, Monotone (fun c1 => Pfail d c1)) :
    Monotone (fun c1 => Pfail (Dstar c1) c1) := by
  intro c1 c1' hc1
  calc Pfail (Dstar c1) c1 ≤ Pfail (Dstar c1') c1 := hPfail_mono1 c1 (hDstar_mono hc1)
    _ ≤ Pfail (Dstar c1') c1' := hPfail_mono2 (Dstar c1') hc1

/-- **Theorem `thm:main`**, part (b), STRICT clause: "it is strictly increasing when
raising `c1` moves a positive-probability set of coupled paths across the failure
boundary" -- here specialized to the sufficient condition that `Pfail` is strictly
monotone in the threshold `D*` itself (e.g. because `Fails_probability_strict_mono` in
`JumpProcess.lean` supplies a positive-probability crossing set at the level of `D*`),
combined with `Dstar` strictly increasing (always available from `dstar_strictMono`,
since Lemma `lem:phi` gives a strict `Φ(c1) < Φ(c1')` for every `ρ > 0`). Channels 1+2
(via `Dstar`) alone then force strict monotonicity of the composite failure probability,
independent of whether channel 3 (the jump-size effect) is itself strict. -/
theorem Pfail_comp_strictMono {Pfail : ℝ → ℝ → ℝ} {Dstar : ℝ → ℝ}
    (hDstar_mono : StrictMono Dstar)
    (hPfail_mono1 : ∀ c1, StrictMono (fun d => Pfail d c1))
    (hPfail_mono2 : ∀ d, Monotone (fun c1 => Pfail d c1)) :
    StrictMono (fun c1 => Pfail (Dstar c1) c1) := by
  intro c1 c1' hc1
  calc Pfail (Dstar c1) c1 < Pfail (Dstar c1') c1 := hPfail_mono1 c1 (hDstar_mono hc1)
    _ ≤ Pfail (Dstar c1') c1' := hPfail_mono2 (Dstar c1') hc1.le

end Bankruns
