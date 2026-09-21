/-
Formalization of Section V ("The Bridge Theorem") and Appendix B of
Schuler, "Deposits Are Not Options".

This file proves Theorem 2 (the Bridge Theorem, `thm:bridge`) and Corollary 1
(the first-order approximation, `cor:approx`).
-/
import Mathlib
import Bankruns.Phi

open Real Set Filter Topology

noncomputable section

namespace Bankruns

variable {R pi rho : ℝ}

/-- The bridge threshold `p*(ρ, R)` of equation `\eqref{eq:pstar}`. By definition it is
`Φ_shift` evaluated at the zero-premium limit `(c1, c2) = (1, R)`, which is exactly the
object Theorem `thm:bridge` identifies as the ε → 0 limit of the withdrawal condition. -/
def pStar (rho R : ℝ) : ℝ := Phi 1 R rho

lemma pStar_of_ne_one {rho : ℝ} (R : ℝ) (h : rho ≠ 1) :
    pStar rho R = (2 ^ (1 - rho) - 1) / ((1 + R) ^ (1 - rho) - 1) := by
  unfold pStar; rw [Phi_of_ne_one h]; norm_num

lemma pStar_of_eq_one (R : ℝ) : pStar 1 R = Real.log 2 / Real.log (1 + R) := by
  unfold pStar; rw [Phi_of_eq_one]; norm_num

/-! ### Step 2 of Appendix B: the ε → 0 limit at fixed ρ -/

/-- **Bridge Theorem**, Step 2, `ρ ≠ 1` branch: as `c1 → 1⁺` (i.e. `ε = c1 - 1 → 0⁺`) along
the resource constraint, the withdrawal condition `Φ_shift(c1, c2(c1), ρ)` converges to the
bridge threshold `p*(ρ, R)`. -/
theorem bridge_limit_ne_one (R pi rho : ℝ) (hpi1 : pi < 1) (hR : 1 < R) (hrho1 : rho ≠ 1) :
    Tendsto (fun c1 => Phi c1 (c2RC R pi c1) rho) (𝓝[≥] (1:ℝ)) (𝓝 (pStar rho R)) := by
  have hc2one : c2RC R pi 1 = R := by
    have h1pi : (1:ℝ) - pi ≠ 0 := by linarith
    unfold c2RC; field_simp
  have hc1 : (0:ℝ) < 1 + (1:ℝ) := by norm_num
  have hc2pos : (0:ℝ) < c2RC R pi 1 := by rw [hc2one]; linarith
  have hderiv := hasDerivAt_Phi_resource (R := R) (pi := pi) (rho := rho) hc1 hc2pos hrho1
  have hcontF : ContinuousAt (fun c1 => Phi c1 (c2RC R pi c1) rho) 1 := hderiv.continuousAt
  have hcontF' : Tendsto (fun c1 => Phi c1 (c2RC R pi c1) rho) (𝓝 1)
      (𝓝 (Phi 1 (c2RC R pi 1) rho)) := hcontF
  have hval : Phi 1 (c2RC R pi 1) rho = pStar rho R := by rw [hc2one]; rfl
  rw [hval] at hcontF'
  exact hcontF'.mono_left nhdsWithin_le_nhds

/-- **Bridge Theorem**, Step 2, `ρ = 1` (log-utility) branch. -/
theorem bridge_limit_eq_one (R pi : ℝ) (hpi1 : pi < 1) (hR : 1 < R) :
    Tendsto (fun c1 => Phi c1 (c2RC R pi c1) 1) (𝓝[≥] (1:ℝ)) (𝓝 (pStar 1 R)) := by
  have hc2one : c2RC R pi 1 = R := by
    have h1pi : (1:ℝ) - pi ≠ 0 := by linarith
    unfold c2RC; field_simp
  have hc1 : (0:ℝ) < 1 + (1:ℝ) := by norm_num
  have hc2pos : (0:ℝ) < c2RC R pi 1 := by rw [hc2one]; linarith
  have hderiv := hasDerivAt_Phi_resource_log (R := R) (pi := pi) hc1 hc2pos
  have hcontF : ContinuousAt (fun c1 => Phi c1 (c2RC R pi c1) 1) 1 := hderiv.continuousAt
  have hcontF' : Tendsto (fun c1 => Phi c1 (c2RC R pi c1) 1) (𝓝 1)
      (𝓝 (Phi 1 (c2RC R pi 1) 1)) := hcontF
  have hval : Phi 1 (c2RC R pi 1) 1 = pStar 1 R := by rw [hc2one]; rfl
  rw [hval] at hcontF'
  exact hcontF'.mono_left nhdsWithin_le_nhds

/-- **Bridge Theorem** (`thm:bridge`), Step 2, combined statement: for every risk-aversion
parameter `ρ > 0`, as `c1 → 1⁺` along the resource constraint, `Φ_shift(c1, c2(c1), ρ)`
converges to the bridge threshold `p*(ρ, R)`. -/
theorem bridge_limit (hpi1 : pi < 1) (hR : 1 < R) :
    Tendsto (fun c1 => Phi c1 (c2RC R pi c1) rho) (𝓝[≥] (1:ℝ)) (𝓝 (pStar rho R)) := by
  rcases eq_or_ne rho 1 with h | h
  · subst h; exact bridge_limit_eq_one R pi hpi1 hR
  · exact bridge_limit_ne_one R pi rho hpi1 hR h

/-! ### Step 3 of Appendix B: continuity of `p*` at `ρ = 1` (L'Hôpital's rule) -/

/-- **Bridge Theorem**, Step 3: `Φ_shift(c1, c2, ·)` is continuous at `ρ = 1`, for any fixed
`c1, c2 > 0`. Applied at `(c1, c2) = (1, R)` this is the continuity of the bridge threshold
`p*(·, R)` at `ρ = 1`, established in the paper by L'Hôpital's rule. -/
theorem Phi_continuousAt_rho_one {c1 c2 : ℝ} (hc1 : 0 < c1) (hc2 : 0 < c2) :
    ContinuousAt (fun rho => Phi c1 c2 rho) 1 := by
  have hc1' : (0:ℝ) < 1 + c1 := by linarith
  have hc2' : (0:ℝ) < 1 + c2 := by linarith
  have hlog1ne : Real.log (1 + c1) ≠ 0 := (Real.log_pos (by linarith)).ne'
  have hlog2ne : Real.log (1 + c2) ≠ 0 := (Real.log_pos (by linarith)).ne'
  set f : ℝ → ℝ := fun rho => (1 + c1) ^ (1 - rho) - 1 with hf_def
  set g : ℝ → ℝ := fun rho => (1 + c2) ^ (1 - rho) - 1 with hg_def
  -- the "raw" powers, before subtracting 1, and their derivatives at every point
  have hpw1 : ∀ rho : ℝ, HasDerivAt (fun t => (1 + c1) ^ (1 - t))
      (Real.log (1 + c1) * (-1) * (1 + c1) ^ (1 - rho)) rho := by
    intro rho
    have h1 : HasDerivAt (fun rho : ℝ => 1 - rho) (-1) rho := (hasDerivAt_id' rho).const_sub 1
    exact h1.const_rpow hc1'
  have hpw2 : ∀ rho : ℝ, HasDerivAt (fun t => (1 + c2) ^ (1 - t))
      (Real.log (1 + c2) * (-1) * (1 + c2) ^ (1 - rho)) rho := by
    intro rho
    have h1 : HasDerivAt (fun rho : ℝ => 1 - rho) (-1) rho := (hasDerivAt_id' rho).const_sub 1
    exact h1.const_rpow hc2'
  have hderiv_f : ∀ rho : ℝ, HasDerivAt f (-(Real.log (1 + c1) * (1 + c1) ^ (1 - rho))) rho := by
    intro rho
    have h3 := (hpw1 rho).sub_const 1
    have heq : Real.log (1 + c1) * (-1) * (1 + c1) ^ (1 - rho) =
        -(Real.log (1 + c1) * (1 + c1) ^ (1 - rho)) := by ring
    rwa [heq] at h3
  have hderiv_g : ∀ rho : ℝ, HasDerivAt g (-(Real.log (1 + c2) * (1 + c2) ^ (1 - rho))) rho := by
    intro rho
    have h3 := (hpw2 rho).sub_const 1
    have heq : Real.log (1 + c2) * (-1) * (1 + c2) ^ (1 - rho) =
        -(Real.log (1 + c2) * (1 + c2) ^ (1 - rho)) := by ring
    rwa [heq] at h3
  have hgderiv_ne : ∀ rho : ℝ, -(Real.log (1 + c2) * (1 + c2) ^ (1 - rho)) ≠ 0 := by
    intro rho
    have hp : 0 < (1 + c2) ^ (1 - rho) := Real.rpow_pos_of_pos hc2' _
    exact neg_ne_zero.mpr (mul_ne_zero hlog2ne hp.ne')
  have hf0 : f 1 = 0 := by simp [hf_def]
  have hg0 : g 1 = 0 := by simp [hg_def]
  have hf_to_zero : Tendsto f (𝓝[≠] (1:ℝ)) (𝓝 0) := by
    have hc : Tendsto f (𝓝 1) (𝓝 (f 1)) := (hderiv_f 1).continuousAt
    rw [hf0] at hc
    exact hc.mono_left nhdsWithin_le_nhds
  have hg_to_zero : Tendsto g (𝓝[≠] (1:ℝ)) (𝓝 0) := by
    have hc : Tendsto g (𝓝 1) (𝓝 (g 1)) := (hderiv_g 1).continuousAt
    rw [hg0] at hc
    exact hc.mono_left nhdsWithin_le_nhds
  have hcont_f' : ContinuousAt (fun rho : ℝ => -(Real.log (1 + c1) * (1 + c1) ^ (1 - rho))) 1 :=
    ((hpw1 1).continuousAt.const_mul (Real.log (1 + c1))).neg
  have hcont_g' : ContinuousAt (fun rho : ℝ => -(Real.log (1 + c2) * (1 + c2) ^ (1 - rho))) 1 :=
    ((hpw2 1).continuousAt.const_mul (Real.log (1 + c2))).neg
  have hratio_cont : ContinuousAt
      (fun rho : ℝ => (-(Real.log (1 + c1) * (1 + c1) ^ (1 - rho))) /
        (-(Real.log (1 + c2) * (1 + c2) ^ (1 - rho)))) 1 :=
    hcont_f'.div hcont_g' (hgderiv_ne 1)
  have hratio_lim : Tendsto
      (fun rho : ℝ => (-(Real.log (1 + c1) * (1 + c1) ^ (1 - rho))) /
        (-(Real.log (1 + c2) * (1 + c2) ^ (1 - rho))))
      (𝓝[≠] (1:ℝ)) (𝓝 (Real.log (1 + c1) / Real.log (1 + c2))) := by
    have hc : Tendsto
        (fun rho : ℝ => (-(Real.log (1 + c1) * (1 + c1) ^ (1 - rho))) /
          (-(Real.log (1 + c2) * (1 + c2) ^ (1 - rho)))) (𝓝 1)
        (𝓝 ((-(Real.log (1 + c1) * (1 + c1) ^ (1 - (1:ℝ)))) /
          (-(Real.log (1 + c2) * (1 + c2) ^ (1 - (1:ℝ)))))) := hratio_cont
    have hval : (-(Real.log (1 + c1) * (1 + c1) ^ (1 - (1:ℝ)))) /
        (-(Real.log (1 + c2) * (1 + c2) ^ (1 - (1:ℝ)))) =
        Real.log (1 + c1) / Real.log (1 + c2) := by norm_num
    rw [hval] at hc
    exact hc.mono_left nhdsWithin_le_nhds
  have hlim : Tendsto (fun rho => f rho / g rho) (𝓝[≠] (1:ℝ))
      (𝓝 (Real.log (1 + c1) / Real.log (1 + c2))) :=
    HasDerivAt.lhopital_zero_nhdsNE (Eventually.of_forall hderiv_f)
      (Eventually.of_forall hderiv_g) (Eventually.of_forall hgderiv_ne)
      hf_to_zero hg_to_zero hratio_lim
  have hEq : (fun rho => Phi c1 c2 rho) =ᶠ[𝓝[≠] (1:ℝ)] (fun rho => f rho / g rho) := by
    filter_upwards [self_mem_nhdsWithin] with rho hrho
    exact Phi_of_ne_one hrho
  have hlim2 : Tendsto (fun rho => Phi c1 c2 rho) (𝓝[≠] (1:ℝ))
      (𝓝 (Real.log (1 + c1) / Real.log (1 + c2))) :=
    hlim.congr' hEq.symm
  have hval1 : Phi c1 c2 1 = Real.log (1 + c1) / Real.log (1 + c2) := Phi_of_eq_one c1 c2
  have hlim2' : Tendsto (fun rho => Phi c1 c2 rho) (𝓝[≠] (1:ℝ)) (𝓝 (Phi c1 c2 1)) := by
    rw [hval1]; exact hlim2
  show Tendsto (fun rho => Phi c1 c2 rho) (𝓝 (1:ℝ)) (𝓝 (Phi c1 c2 1))
  rw [← nhdsNE_sup_pure (1:ℝ)]
  exact hlim2'.sup (tendsto_pure_nhds _ _)

/-- **Bridge Theorem** (`thm:bridge`), full statement: `p*` is continuous at `ρ = 1`. -/
theorem pStar_continuousAt_one (R : ℝ) (hR : 1 < R) : ContinuousAt (fun rho => pStar rho R) 1 :=
  Phi_continuousAt_rho_one (by norm_num) (by linarith)

/-! ### Corollary `cor:approx`: the first-order approximation -/

/-- The slope `M(ρ, R, π)` of equation `\eqref{eq:approx}`: the derivative of
`Φ_shift(1+ε, c2(ε), ρ)` with respect to `ε` at `ε = 0`, i.e. the derivative of
`Φ_shift(c1, c2(c1), ρ)` with respect to `c1` at `c1 = 1`. -/
def approxSlope (rho R pi : ℝ) : ℝ :=
  (((1 - rho) * (1 + (1:ℝ)) ^ ((1 - rho) - 1)) * ((1 + R) ^ (1 - rho) - 1) -
      ((1 + (1:ℝ)) ^ (1 - rho) - 1) *
        ((1 - rho) * (1 + R) ^ ((1 - rho) - 1) * (-(R * pi / (1 - pi))))) /
    ((1 + R) ^ (1 - rho) - 1) ^ 2

/-- **Corollary 1** (`cor:approx`), `ρ ≠ 1` case: `Φ_shift(1+ε, c2(ε), ρ)` has derivative
`M(ρ, R, π) = approxSlope ρ R π` at `ε = 0` (i.e. at `c1 = 1`), and `M > 0`. -/
theorem hasDerivAt_approx (R pi rho : ℝ) (hpi0 : 0 < pi) (hpi1 : pi < 1) (hR : 1 < R)
    (hrho1 : rho ≠ 1) :
    HasDerivAt (fun c1 => Phi c1 (c2RC R pi c1) rho) (approxSlope rho R pi) 1 := by
  have hc2one : c2RC R pi 1 = R := by
    have h1pi : (1:ℝ) - pi ≠ 0 := by linarith
    unfold c2RC; field_simp
  have hc1 : (0:ℝ) < 1 + (1:ℝ) := by norm_num
  have hc2pos : (0:ℝ) < c2RC R pi 1 := by rw [hc2one]; linarith
  have hderiv := hasDerivAt_Phi_resource (R := R) (pi := pi) (rho := rho) hc1 hc2pos hrho1
  rw [hc2one] at hderiv
  exact hderiv

/-- **Corollary 1** (`cor:approx`): the slope `M(ρ, R, π)` is strictly positive, so
`Φ_shift(ε) > p^*(ρ, R)` for every `ε > 0` (matching the paper's "same α² argument as
Lemma `lem:phi`"). -/
theorem approxSlope_pos (R pi rho : ℝ) (hpi0 : 0 < pi) (hpi1 : pi < 1) (hR : 1 < R)
    (hrho1 : rho ≠ 1) : 0 < approxSlope rho R pi := by
  have hc2one : c2RC R pi 1 = R := by
    have h1pi : (1:ℝ) - pi ≠ 0 := by linarith
    unfold c2RC; field_simp
  have hRpos : (0:ℝ) < R := by linarith
  have hc1pos : (0:ℝ) < (1:ℝ) := one_pos
  have hc2pos : (0:ℝ) < c2RC R pi 1 := by rw [hc2one]; linarith
  have := Phi_resource_deriv_pos (R := R) (pi := pi) (rho := rho) (c1 := 1)
    hpi0 hpi1 hRpos hc1pos hc2pos hrho1
  rwa [hc2one] at this

/-! ### The bridge threshold is a proper probability, and the boundary case `p_S = 1`

Appendix B's closing remark: "Since `R > 1`, we have `1 + R > 2`, ... giving `p* < 1`.
Clearly `p* > 0`. Hence the threshold is a proper probability." Section V's
"Generalization to risky withdrawal" then uses `p* < 1` to conclude that certain full
recovery from staying (`p_S = 1`) always implies staying, when `R > 1`. -/

/-- `p*(ρ, R) ∈ (0, 1)`: a proper probability, for every `ρ` and every `R > 1`. This is
Regularity condition (R2) (`Phi_lt_one_of_lt`/`Phi_pos_of_pos`) specialized at
`(c1, c2) = (1, R)`. -/
theorem pStar_lt_one (R : ℝ) (hR : 1 < R) (rho : ℝ) : pStar rho R < 1 :=
  Phi_lt_one_of_lt one_pos hR rho

theorem pStar_pos (R : ℝ) (hR : 1 < R) (rho : ℝ) : 0 < pStar rho R :=
  Phi_pos_of_pos one_pos (by linarith) rho

/-- **Boundary case of the generalized bridge condition**, `\eqref{eq:generalcondlimit}`:
if staying yields full recovery with certainty (`p_S = 1`), the generalized withdrawal
condition `p_S ≤ p_W · p^*(ρ, R)` can never hold when `R > 1`, since `p_W ≤ 1` and
`p^*(ρ, R) < 1` force `p_W · p^*(ρ, R) < 1 = p_S`. "Thus certain full recovery from
staying implies staying." -/
theorem not_generalcondlimit_of_pS_eq_one (R rho pW : ℝ) (hR : 1 < R) (hpW : pW ≤ 1) :
    ¬ ((1:ℝ) ≤ pW * pStar rho R) := by
  have h1 : pStar rho R < 1 := pStar_lt_one R hR rho
  have h2 : (0:ℝ) < pStar rho R := pStar_pos R hR rho
  have h3 : pW * pStar rho R ≤ 1 * pStar rho R :=
    mul_le_mul_of_nonneg_right hpW h2.le
  simp only [one_mul] at h3
  linarith

/-! ### The generalized bridge condition, `\eqref{eq:generalbridge}` ⟺ `\eqref{eq:generalcond}`

The rearrangement from the utility-consistent comparison `p_W u(c1) + (1-p_W) u(0) ≥
p_S u(c2) + (1-p_S) u(0)` to `p_S ≤ p_W Φ(c1,c2,ρ)` is division by the positive quantity
`u(c2) - u(0)`; we record this as the general algebraic fact it is (independent of the
specific utility function), then specialize it to `Φ`. -/

theorem generalbridge_iff_generalcond (A B pW pS : ℝ) (hB : 0 < B) :
    pS * B ≤ pW * A ↔ pS ≤ pW * (A / B) := by
  rw [← mul_div_assoc, le_div_iff₀ hB]

end Bankruns
