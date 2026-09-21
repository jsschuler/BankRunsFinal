/-
Formalization of Lemma `lem:jump` ("Channel 3: the jump-size effect"), Appendix A of
Schuler, "Deposits Are Not Options".

We build the finite-agent sequential-service jump process explicitly: agents are
processed one at a time (indexed by `t : ℕ`); at each step the pool `D(t)` either absorbs
a withdrawal of size `c1` (if the currently-processed agent has an exogenous liquidity
shock, encoded by `shocks t = true`, or if the pool has already fallen to or below the
fixed threshold `D*`) or is left unchanged. Two economies with payments `c1 ≤ c1'` are run
on the SAME realization `shocks : ℕ → Bool` (the same exogenous-shock pattern and
processing order) and the same fixed threshold `D*` -- this is the paper's coupling
construction. We prove:

1. `step_mono` / `Dpath_mono`: pathwise domination `D'(t) ≤ D(t)` for every `t` and every
   realization (the coupling argument of the Lemma `lem:jump` proof).
2. `Fails_mono`: the failure event `{τ < T}` (pool exhausted by time `T`) is monotone in
   `c1` for every fixed realization, i.e. `{τ < T} ⊆ {τ' < T}` pointwise.
3. `Fails_probability_mono`: hence, under ANY probability distribution over realizations
   (any `PMF (ℕ → Bool)`; this is not restricted to the uniform or i.i.d. Bernoulli case),
   `P(τ < T) ≤ P(τ' < T)` -- the paper's conclusion "the larger withdrawal payment weakly
   increases the failure probability at any fixed pool and withdrawal region".
-/
import Mathlib

open Set

noncomputable section

namespace Bankruns

/-- One step of the sequential-service jump process: the currently-processed agent
withdraws (decrementing the pool by `c1`) either because of an exogenous liquidity shock
(`shock = true`) or because the pool has already fallen to or below the fixed threshold
`D*`; otherwise the pool is unchanged. -/
def step (c1 Dstar : ℝ) (shock : Bool) (D : ℝ) : ℝ :=
  if shock = true ∨ D ≤ Dstar then D - c1 else D

/-- The single-step coupling inequality: if the smaller-payment economy's pool `D`
dominates the larger-payment economy's pool `D'` before this step, it still does after
the step, given `0 ≤ c1 ≤ c1'` and the SAME shock realization and threshold. This is the
case-by-case argument of the Lemma `lem:jump` proof. -/
theorem step_mono {c1 c1' Dstar D D' : ℝ} (hc1 : 0 ≤ c1) (hle : c1 ≤ c1') (hDD' : D' ≤ D)
    (shock : Bool) :
    step c1' Dstar shock D' ≤ step c1 Dstar shock D := by
  have hc1' : 0 ≤ c1' := hc1.trans hle
  unfold step
  by_cases hg : shock = true ∨ D ≤ Dstar
  · have hg' : shock = true ∨ D' ≤ Dstar := hg.imp id (fun h => hDD'.trans h)
    rw [if_pos hg, if_pos hg']
    linarith
  · rw [if_neg hg]
    by_cases hg' : shock = true ∨ D' ≤ Dstar
    · rw [if_pos hg']
      linarith
    · rw [if_neg hg']
      exact hDD'

/-- The deposit pool path under payment `c1`, fixed threshold `D*`, initial pool `D0`, and
realization `shocks : ℕ → Bool` (the exogenous-shock pattern of the sequentially
processed agents). -/
def Dpath (c1 Dstar D0 : ℝ) (shocks : ℕ → Bool) : ℕ → ℝ
  | 0 => D0
  | (t + 1) => step c1 Dstar (shocks t) (Dpath c1 Dstar D0 shocks t)

/-- **Lemma `lem:jump`, pathwise coupling**: for every realization and every time `t`, the
larger-payment economy's pool is dominated by the smaller-payment economy's pool. -/
theorem Dpath_mono {c1 c1' Dstar D0 : ℝ} (hc1 : 0 ≤ c1) (hle : c1 ≤ c1') (shocks : ℕ → Bool) :
    ∀ t, Dpath c1' Dstar D0 shocks t ≤ Dpath c1 Dstar D0 shocks t := by
  intro t
  induction t with
  | zero => simp [Dpath]
  | succ t ih =>
    show step c1' Dstar (shocks t) (Dpath c1' Dstar D0 shocks t) ≤
        step c1 Dstar (shocks t) (Dpath c1 Dstar D0 shocks t)
    exact step_mono hc1 hle ih (shocks t)

/-- The failure event: the pool is exhausted (reaches `≤ 0`) at or before time `T`. -/
def Fails (c1 Dstar D0 : ℝ) (shocks : ℕ → Bool) (T : ℕ) : Prop :=
  ∃ t ≤ T, Dpath c1 Dstar D0 shocks t ≤ 0

/-- **Lemma `lem:jump`, failure-event monotonicity**: for every fixed realization, the
larger payment weakly enlarges the failure event. -/
theorem Fails_mono {c1 c1' Dstar D0 : ℝ} (hc1 : 0 ≤ c1) (hle : c1 ≤ c1') {shocks : ℕ → Bool}
    {T : ℕ} (h : Fails c1 Dstar D0 shocks T) : Fails c1' Dstar D0 shocks T := by
  obtain ⟨t, htT, ht⟩ := h
  exact ⟨t, htT, (Dpath_mono hc1 hle shocks t).trans ht⟩

theorem Fails_subset {c1 c1' Dstar D0 : ℝ} (hc1 : 0 ≤ c1) (hle : c1 ≤ c1') (T : ℕ) :
    {shocks : ℕ → Bool | Fails c1 Dstar D0 shocks T} ⊆
      {shocks : ℕ → Bool | Fails c1' Dstar D0 shocks T} :=
  fun _ h => Fails_mono hc1 hle h

/-- **Lemma `lem:jump`, full statement**: under ANY distribution over realizations, the
failure probability is weakly increasing in the payment `c1`, for any fixed threshold
`D*` and initial pool `D0` -- the "jump-size effect" (Channel 3 of Theorem `thm:main`). -/
theorem Fails_probability_mono {c1 c1' Dstar D0 : ℝ} (hc1 : 0 ≤ c1) (hle : c1 ≤ c1')
    (T : ℕ) (p : PMF (ℕ → Bool)) :
    p.toOuterMeasure {shocks | Fails c1 Dstar D0 shocks T} ≤
      p.toOuterMeasure {shocks | Fails c1' Dstar D0 shocks T} :=
  p.toOuterMeasure_mono
    ((Set.inter_subset_left).trans (Fails_subset hc1 hle T))

/-! ### The strict clause of Lemma `lem:jump`

"It is strictly increasing if a positive-probability set of coupled paths survives under
`c1` but fails under `c1' > c1`." We prove this in full generality for `PMF.toOuterMeasure`
(any `PMF`, any disjoint sets), then specialize to the failure events. -/

theorem outerMeasure_union_of_disjoint {α : Type*} (p : PMF α) {s t : Set α}
    (h : Disjoint s t) :
    p.toOuterMeasure (s ∪ t) = p.toOuterMeasure s + p.toOuterMeasure t := by
  simp only [PMF.toOuterMeasure_apply]
  have heq : ∀ x, (s ∪ t).indicator p x = s.indicator p x + t.indicator p x :=
    fun x => congrFun (Set.indicator_union_of_disjoint h p) x
  simp_rw [heq]
  exact ENNReal.tsum_add

theorem outerMeasure_le_one {α : Type*} (p : PMF α) (s : Set α) :
    p.toOuterMeasure s ≤ 1 := by
  have h1 : p.toOuterMeasure s ≤ p.toOuterMeasure Set.univ :=
    p.toOuterMeasure.mono (Set.subset_univ s)
  have h2 : p.toOuterMeasure Set.univ = 1 := by
    rw [PMF.toOuterMeasure_apply]
    simp only [Set.indicator_univ]
    exact p.tsum_coe
  rwa [h2] at h1

/-- If `s ⊆ t` and the "crossing set" `t \ s` has positive probability, the probability
of `t` strictly exceeds that of `s`. -/
theorem outerMeasure_strict_mono_of_pos {α : Type*} (p : PMF α) {s t : Set α}
    (hsub : s ⊆ t) (hpos : 0 < p.toOuterMeasure (t \ s)) :
    p.toOuterMeasure s < p.toOuterMeasure t := by
  have hunion : s ∪ (t \ s) = t := by
    ext x
    constructor
    · rintro (hx | ⟨hx, -⟩)
      · exact hsub hx
      · exact hx
    · intro hx
      by_cases hxs : x ∈ s
      · exact Or.inl hxs
      · exact Or.inr ⟨hx, hxs⟩
  have hdisjoint : Disjoint s (t \ s) := Set.disjoint_left.mpr fun x hxs hxts => hxts.2 hxs
  have hne : p.toOuterMeasure s ≠ ⊤ :=
    ne_top_of_le_ne_top ENNReal.one_ne_top (outerMeasure_le_one p s)
  calc p.toOuterMeasure s < p.toOuterMeasure s + p.toOuterMeasure (t \ s) :=
        ENNReal.lt_add_right hne hpos.ne'
    _ = p.toOuterMeasure (s ∪ (t \ s)) := (outerMeasure_union_of_disjoint p hdisjoint).symm
    _ = p.toOuterMeasure t := by rw [hunion]

/-- **Lemma `lem:jump`, strict clause**: if a positive-probability set of realizations
survives under `c1` but fails under `c1' > c1`, the failure probability is STRICTLY
higher under `c1'`. -/
theorem Fails_probability_strict_mono {c1 c1' Dstar D0 : ℝ} (hc1 : 0 ≤ c1) (hlt : c1 < c1')
    (T : ℕ) (p : PMF (ℕ → Bool))
    (hpos : 0 < p.toOuterMeasure
      ({shocks | Fails c1' Dstar D0 shocks T} \ {shocks | Fails c1 Dstar D0 shocks T})) :
    p.toOuterMeasure {shocks | Fails c1 Dstar D0 shocks T} <
      p.toOuterMeasure {shocks | Fails c1' Dstar D0 shocks T} :=
  outerMeasure_strict_mono_of_pos p (Fails_subset hc1 hlt.le T) hpos

end Bankruns
