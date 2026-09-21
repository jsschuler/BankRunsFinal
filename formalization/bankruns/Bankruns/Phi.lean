/-
Formalization of Section II ("The Diamond-Dybvig Model and the Option Premium") and
Appendix A of Schuler, "Deposits Are Not Options".

This file defines the shifted-CRRA withdrawal threshold `Phi c1 c2 rho` (equation
`\eqref{eq:phishiftA}` / `\eqref{eq:phi}` in the paper) and the Diamond-Dybvig resource
constraint `c2RC`, and proves Proposition 1 / Lemma `lem:phi`: along the resource
constraint, the withdrawal threshold is strictly increasing in the early-withdrawal
payment `c1`, for every risk-aversion parameter `rho > 0` (both `rho ≠ 1` and the
log-utility case `rho = 1`).
-/
import Mathlib

open Real Set Filter

noncomputable section

namespace Bankruns

/-- The shifted-CRRA withdrawal threshold `Φ_shift(c1, c2, ρ)` of equation
`\eqref{eq:phishiftA}`. For `ρ ≠ 1` it is `((1+c1)^(1-ρ) - 1) / ((1+c2)^(1-ρ) - 1)`;
for `ρ = 1` (log utility) it is `log(1+c1) / log(1+c2)`. -/
def Phi (c1 c2 rho : ℝ) : ℝ :=
  if rho = 1 then Real.log (1 + c1) / Real.log (1 + c2)
  else ((1 + c1) ^ (1 - rho) - 1) / ((1 + c2) ^ (1 - rho) - 1)

@[simp] lemma Phi_of_ne_one {c1 c2 rho : ℝ} (h : rho ≠ 1) :
    Phi c1 c2 rho = ((1 + c1) ^ (1 - rho) - 1) / ((1 + c2) ^ (1 - rho) - 1) := by
  simp [Phi, h]

@[simp] lemma Phi_of_eq_one (c1 c2 : ℝ) :
    Phi c1 c2 1 = Real.log (1 + c1) / Real.log (1 + c2) := by
  simp [Phi]

/-- The Diamond-Dybvig resource constraint at the fundamental-equilibrium withdrawal
fraction `n = π` (equation `\eqref{eq:c2deriv}`): `c2(c1) = R(1 - π c1)/(1 - π)`. -/
def c2RC (R pi c1 : ℝ) : ℝ := R * (1 - pi * c1) / (1 - pi)

/-- `c2RC` is affine and strictly decreasing in `c1`, with slope `-Rπ/(1-π)`
(Channel 2, "the continuation value effect", equation `\eqref{eq:c2deriv}`). -/
lemma hasDerivAt_c2RC (R pi c1 : ℝ) :
    HasDerivAt (fun c1 => c2RC R pi c1) (-(R * pi / (1 - pi))) c1 := by
  have h1 : HasDerivAt (fun c1 : ℝ => (1 : ℝ) - pi * c1) (-pi) c1 := by
    have h := ((hasDerivAt_id' c1).const_mul pi).const_sub (1 : ℝ)
    have heq : -(pi * 1) = (-pi : ℝ) := by ring
    rwa [heq] at h
  have h2 : HasDerivAt (fun c1 : ℝ => R * (1 - pi * c1)) (R * (-pi)) c1 := h1.const_mul R
  have h3 : HasDerivAt (fun c1 : ℝ => R * (1 - pi * c1) / (1 - pi)) (R * (-pi) / (1 - pi)) c1 :=
    h2.div_const (1 - pi)
  have heq2 : R * (-pi) / (1 - pi) = -(R * pi / (1 - pi)) := by ring
  rw [heq2] at h3
  have hfeq : (fun c1 : ℝ => R * (1 - pi * c1) / (1 - pi)) = (fun c1 => c2RC R pi c1) := rfl
  rwa [hfeq] at h3

/-- `(1+x)^α - 1` is strictly positive when `x > 0` and `α > 0`. -/
lemma rpow_sub_one_sign_pos {x alpha : ℝ} (hx : 0 < x) (halpha : 0 < alpha) :
    0 < (1 + x) ^ alpha - 1 := by
  have hx1 : (1 : ℝ) < 1 + x := by linarith
  have := Real.one_lt_rpow hx1 halpha
  linarith

/-- `(1+x)^α - 1` is strictly negative when `x > 0` and `α < 0`. -/
lemma rpow_sub_one_sign_neg {x alpha : ℝ} (hx : 0 < x) (halpha : alpha < 0) :
    (1 + x) ^ alpha - 1 < 0 := by
  have hx1 : (1 : ℝ) < 1 + x := by linarith
  have := Real.rpow_lt_one_of_one_lt_of_neg hx1 halpha
  linarith

/-- `(1+x)^α - 1 ≠ 0` for `x > 0`, `α ≠ 0`. -/
lemma rpow_sub_one_ne_zero {x alpha : ℝ} (hx : 0 < x) (halpha : alpha ≠ 0) :
    (1 + x) ^ alpha - 1 ≠ 0 := by
  rcases lt_or_gt_of_ne halpha with h | h
  · exact (rpow_sub_one_sign_neg hx h).ne
  · exact (rpow_sub_one_sign_pos hx h).ne'

/-- The derivative of `c1 ↦ (1+c1)^α - 1`. -/
lemma hasDerivAt_rpow_sub_one {c1 alpha : ℝ} (hc1 : (0:ℝ) < 1 + c1) :
    HasDerivAt (fun c1 => (1 + c1) ^ alpha - 1) (alpha * (1 + c1) ^ (alpha - 1)) c1 := by
  have hbase : HasDerivAt (fun c1 : ℝ => 1 + c1) 1 c1 := (hasDerivAt_id' c1).const_add (1:ℝ)
  have hpow := hbase.rpow_const (p := alpha) (Or.inl hc1.ne')
  have hsub := hpow.sub_const 1
  have heq : (1:ℝ) * alpha * (1 + c1) ^ (alpha - 1) = alpha * (1 + c1) ^ (alpha - 1) := by ring
  rwa [heq] at hsub

variable {R pi rho : ℝ}

/-- The quotient-rule derivative of `Φ_shift(c1, c2(c1), ρ)` at a single point `c1`
(reusable standalone version of the computation inside `phi_resource_strictMonoOn_of_ne_one`,
needed again for the first-order expansion of Corollary `cor:approx`). -/
theorem hasDerivAt_Phi_resource {c1 : ℝ} (hc1 : (0:ℝ) < 1 + c1)
    (hc2pos : (0:ℝ) < c2RC R pi c1) (hrho1 : rho ≠ 1) :
    HasDerivAt (fun c1 => Phi c1 (c2RC R pi c1) rho)
      ((((1 - rho) * (1 + c1) ^ ((1 - rho) - 1)) * ((1 + c2RC R pi c1) ^ (1 - rho) - 1) -
          ((1 + c1) ^ (1 - rho) - 1) *
            ((1 - rho) * (1 + c2RC R pi c1) ^ ((1 - rho) - 1) * (-(R * pi / (1 - pi))))) /
        ((1 + c2RC R pi c1) ^ (1 - rho) - 1) ^ 2) c1 := by
  have hc2 : (0:ℝ) < 1 + c2RC R pi c1 := by linarith
  have hderiv_f : HasDerivAt (fun c1 => (1 + c1) ^ (1 - rho) - 1)
      ((1 - rho) * (1 + c1) ^ ((1 - rho) - 1)) c1 := hasDerivAt_rpow_sub_one hc1
  have hderiv_g : HasDerivAt (fun c1 => (1 + c2RC R pi c1) ^ (1 - rho) - 1)
      ((1 - rho) * (1 + c2RC R pi c1) ^ ((1 - rho) - 1) * (-(R * pi / (1 - pi)))) c1 := by
    have hcomp : HasDerivAt (fun c1 => 1 + c2RC R pi c1) (-(R * pi / (1 - pi))) c1 :=
      (hasDerivAt_c2RC R pi c1).const_add (1:ℝ)
    have hpow := hcomp.rpow_const (p := 1 - rho) (Or.inl hc2.ne')
    have hsub := hpow.sub_const 1
    have heq : (-(R * pi / (1 - pi))) * (1 - rho) * (1 + c2RC R pi c1) ^ ((1 - rho) - 1) =
        (1 - rho) * (1 + c2RC R pi c1) ^ ((1 - rho) - 1) * (-(R * pi / (1 - pi))) := by ring
    rwa [heq] at hsub
  have hgne : (1 + c2RC R pi c1) ^ (1 - rho) - 1 ≠ 0 :=
    rpow_sub_one_ne_zero hc2pos (sub_ne_zero.mpr (fun h => hrho1 h.symm))
  have hPhi_eq : (fun c1 => Phi c1 (c2RC R pi c1) rho) =
      (fun c1 => ((1 + c1) ^ (1 - rho) - 1) / ((1 + c2RC R pi c1) ^ (1 - rho) - 1)) := by
    funext c1; exact Phi_of_ne_one hrho1
  rw [hPhi_eq]
  exact hderiv_f.fun_div hderiv_g hgne

/-- Positivity of that derivative (the "α² argument" of Appendix A), as a standalone,
reusable fact. -/
theorem Phi_resource_deriv_pos {c1 : ℝ} (hpi0 : 0 < pi) (hpi1 : pi < 1) (hR : 0 < R)
    (hc1pos : (0:ℝ) < c1) (hc2pos : 0 < c2RC R pi c1) (hrho1 : rho ≠ 1) :
    0 < (((1 - rho) * (1 + c1) ^ ((1 - rho) - 1)) * ((1 + c2RC R pi c1) ^ (1 - rho) - 1) -
          ((1 + c1) ^ (1 - rho) - 1) *
            ((1 - rho) * (1 + c2RC R pi c1) ^ ((1 - rho) - 1) * (-(R * pi / (1 - pi))))) /
        ((1 + c2RC R pi c1) ^ (1 - rho) - 1) ^ 2 := by
  have halpha_ne : (1:ℝ) - rho ≠ 0 := sub_ne_zero.mpr (fun h => hrho1 h.symm)
  have hmu_pos : 0 < R * pi / (1 - pi) := by
    have h1pi : 0 < 1 - pi := by linarith
    positivity
  have hc1 : (0:ℝ) < 1 + c1 := by linarith
  have hc2 : (0:ℝ) < 1 + c2RC R pi c1 := by linarith
  have hApos : 0 < (1 + c1) ^ ((1 - rho) - 1) := Real.rpow_pos_of_pos hc1 _
  have hBpos : 0 < (1 + c2RC R pi c1) ^ ((1 - rho) - 1) := Real.rpow_pos_of_pos hc2 _
  have hgne : (1 + c2RC R pi c1) ^ (1 - rho) - 1 ≠ 0 := rpow_sub_one_ne_zero hc2pos halpha_ne
  have hgsq_pos : 0 < ((1 + c2RC R pi c1) ^ (1 - rho) - 1) ^ 2 :=
    (sq_nonneg _).lt_of_ne' (pow_ne_zero 2 hgne)
  apply div_pos _ hgsq_pos
  set f := (1 + c1) ^ (1 - rho) - 1 with hf_def
  set g := (1 + c2RC R pi c1) ^ (1 - rho) - 1 with hg_def
  set A := (1 + c1) ^ ((1 - rho) - 1) with hA_def
  set B := (1 + c2RC R pi c1) ^ ((1 - rho) - 1) with hB_def
  set mu := R * pi / (1 - pi) with hmu_def
  show 0 < (1 - rho) * A * g - f * ((1 - rho) * B * (-mu))
  have hexpand : (1 - rho) * A * g - f * ((1 - rho) * B * (-mu)) =
      (1 - rho) * (A * g + mu * (B * f)) := by ring
  rw [hexpand]
  rcases lt_or_gt_of_ne halpha_ne with hneg | hpos
  · have hf_neg : f < 0 := rpow_sub_one_sign_neg hc1pos hneg
    have hg_neg : g < 0 := rpow_sub_one_sign_neg hc2pos hneg
    have h1 : A * g < 0 := mul_neg_of_pos_of_neg hApos hg_neg
    have h2 : mu * (B * f) < 0 := mul_neg_of_pos_of_neg hmu_pos (mul_neg_of_pos_of_neg hBpos hf_neg)
    have hsum_neg : A * g + mu * (B * f) < 0 := by linarith
    exact mul_pos_of_neg_of_neg hneg hsum_neg
  · have hf_pos : 0 < f := rpow_sub_one_sign_pos hc1pos hpos
    have hg_pos : 0 < g := rpow_sub_one_sign_pos hc2pos hpos
    have h1 : 0 < A * g := mul_pos hApos hg_pos
    have h2 : 0 < mu * (B * f) := mul_pos hmu_pos (mul_pos hBpos hf_pos)
    have hsum_pos : 0 < A * g + mu * (B * f) := by linarith
    exact mul_pos hpos hsum_pos

/-- The quotient-rule derivative of `Φ_shift(c1, c2(c1), 1)` (log-utility case) at a
single point `c1`, as a standalone reusable fact. -/
theorem hasDerivAt_Phi_resource_log {c1 : ℝ} (hc1 : (0:ℝ) < 1 + c1)
    (hc2pos : (0:ℝ) < c2RC R pi c1) :
    HasDerivAt (fun c1 => Phi c1 (c2RC R pi c1) 1)
      (((1 / (1 + c1)) * Real.log (1 + c2RC R pi c1) -
          Real.log (1 + c1) * ((-(R * pi / (1 - pi))) / (1 + c2RC R pi c1))) /
        Real.log (1 + c2RC R pi c1) ^ 2) c1 := by
  have hc2 : (0:ℝ) < 1 + c2RC R pi c1 := by linarith
  have hderiv_f : HasDerivAt (fun c1 => Real.log (1 + c1)) (1 / (1 + c1)) c1 := by
    have hbase : HasDerivAt (fun c1 : ℝ => 1 + c1) 1 c1 := (hasDerivAt_id' c1).const_add (1:ℝ)
    simpa using hbase.log hc1.ne'
  have hderiv_g : HasDerivAt (fun c1 => Real.log (1 + c2RC R pi c1))
      ((-(R * pi / (1 - pi))) / (1 + c2RC R pi c1)) c1 := by
    have hcomp : HasDerivAt (fun c1 => 1 + c2RC R pi c1) (-(R * pi / (1 - pi))) c1 :=
      (hasDerivAt_c2RC R pi c1).const_add (1:ℝ)
    simpa using hcomp.log hc2.ne'
  have hgne : Real.log (1 + c2RC R pi c1) ≠ 0 := (Real.log_pos (by linarith)).ne'
  have hPhi_eq : (fun c1 => Phi c1 (c2RC R pi c1) (1:ℝ)) =
      (fun c1 => Real.log (1 + c1) / Real.log (1 + c2RC R pi c1)) := by
    funext c1; exact Phi_of_eq_one c1 (c2RC R pi c1)
  rw [hPhi_eq]
  exact hderiv_f.fun_div hderiv_g hgne

/-- Proposition 1 / Lemma `lem:phi`, `ρ ≠ 1` case: along the resource constraint, the
withdrawal threshold `Φ_shift(c1, c2(c1), ρ)` is strictly increasing in `c1`, for every
`ρ > 0`, `ρ ≠ 1`, on the domain `c1 ∈ (0, 1/π)` where `c2(c1) > 0`. -/
theorem phi_resource_strictMonoOn_of_ne_one (hpi0 : 0 < pi) (hpi1 : pi < 1) (hR : 1 < R)
    (_hrho0 : 0 < rho) (hrho1 : rho ≠ 1) :
    StrictMonoOn (fun c1 => Phi c1 (c2RC R pi c1) rho) (Ioo 0 (1 / pi)) := by
  have hRpos : 0 < R := by linarith
  have hD : Convex ℝ (Ioo (0:ℝ) (1/pi)) := convex_Ioo _ _
  have hIntD : interior (Ioo (0:ℝ) (1/pi)) = Ioo (0:ℝ) (1/pi) := interior_Ioo
  have halpha_ne : (1 : ℝ) - rho ≠ 0 := sub_ne_zero.mpr (fun h => hrho1 h.symm)
  have hmu_pos : 0 < R * pi / (1 - pi) := by positivity
  have hc2pos : ∀ c1 ∈ Ioo (0:ℝ) (1/pi), 0 < c2RC R pi c1 := by
    intro c1 hc1
    obtain ⟨hc1L, hc1U⟩ := hc1
    have hpc1 : pi * c1 < 1 := by
      rw [lt_div_iff₀ hpi0] at hc1U; nlinarith
    have h1pi : 0 < 1 - pi := by linarith
    have hnum : 0 < 1 - pi * c1 := by linarith
    unfold c2RC; positivity
  have hbase1 : ∀ c1 ∈ Ioo (0:ℝ) (1/pi), (0:ℝ) < 1 + c1 := fun c1 hc1 => by linarith [hc1.1]
  have hbase2 : ∀ c1 ∈ Ioo (0:ℝ) (1/pi), (0:ℝ) < 1 + c2RC R pi c1 :=
    fun c1 hc1 => by linarith [hc2pos c1 hc1]
  -- derivative of the numerator f(c1) = (1+c1)^α - 1
  have hderiv_f : ∀ c1 ∈ Ioo (0:ℝ) (1/pi),
      HasDerivAt (fun c1 => (1 + c1) ^ (1 - rho) - 1)
        ((1 - rho) * (1 + c1) ^ ((1 - rho) - 1)) c1 :=
    fun c1 hc1 => hasDerivAt_rpow_sub_one (hbase1 c1 hc1)
  -- derivative of the denominator g(c1) = (1+c2RC(c1))^α - 1
  have hderiv_g : ∀ c1 ∈ Ioo (0:ℝ) (1/pi),
      HasDerivAt (fun c1 => (1 + c2RC R pi c1) ^ (1 - rho) - 1)
        ((1 - rho) * (1 + c2RC R pi c1) ^ ((1 - rho) - 1) * (-(R * pi / (1 - pi)))) c1 := by
    intro c1 hc1
    have hcomp : HasDerivAt (fun c1 => 1 + c2RC R pi c1) (-(R * pi / (1 - pi))) c1 :=
      (hasDerivAt_c2RC R pi c1).const_add (1:ℝ)
    have hpow := hcomp.rpow_const (p := 1 - rho) (Or.inl (hbase2 c1 hc1).ne')
    have hsub := hpow.sub_const 1
    have heq : (-(R * pi / (1 - pi))) * (1 - rho) * (1 + c2RC R pi c1) ^ ((1 - rho) - 1) =
        (1 - rho) * (1 + c2RC R pi c1) ^ ((1 - rho) - 1) * (-(R * pi / (1 - pi))) := by ring
    rwa [heq] at hsub
  have hgne : ∀ c1 ∈ Ioo (0:ℝ) (1/pi),
      (1 + c2RC R pi c1) ^ (1 - rho) - 1 ≠ 0 :=
    fun c1 hc1 => rpow_sub_one_ne_zero (hc2pos c1 hc1) halpha_ne
  -- the ratio and its derivative via the quotient rule
  have hderiv : ∀ c1 ∈ Ioo (0:ℝ) (1/pi),
      HasDerivAt (fun c1 => Phi c1 (c2RC R pi c1) rho)
        ((((1 - rho) * (1 + c1) ^ ((1 - rho) - 1)) * ((1 + c2RC R pi c1) ^ (1 - rho) - 1) -
            ((1 + c1) ^ (1 - rho) - 1) *
              ((1 - rho) * (1 + c2RC R pi c1) ^ ((1 - rho) - 1) * (-(R * pi / (1 - pi))))) /
          ((1 + c2RC R pi c1) ^ (1 - rho) - 1) ^ 2) c1 := by
    intro c1 hc1
    have hPhi_eq : (fun c1 => Phi c1 (c2RC R pi c1) rho) =
        (fun c1 => ((1 + c1) ^ (1 - rho) - 1) / ((1 + c2RC R pi c1) ^ (1 - rho) - 1)) := by
      funext c1; exact Phi_of_ne_one hrho1
    rw [hPhi_eq]
    exact (hderiv_f c1 hc1).fun_div (hderiv_g c1 hc1) (hgne c1 hc1)
  -- positivity of the derivative: the "α² argument" of Appendix A
  have hMpos : ∀ c1 ∈ Ioo (0:ℝ) (1/pi),
      0 < (((1 - rho) * (1 + c1) ^ ((1 - rho) - 1)) * ((1 + c2RC R pi c1) ^ (1 - rho) - 1) -
            ((1 + c1) ^ (1 - rho) - 1) *
              ((1 - rho) * (1 + c2RC R pi c1) ^ ((1 - rho) - 1) * (-(R * pi / (1 - pi))))) /
          ((1 + c2RC R pi c1) ^ (1 - rho) - 1) ^ 2 := by
    intro c1 hc1
    have hApos : 0 < (1 + c1) ^ ((1 - rho) - 1) := Real.rpow_pos_of_pos (hbase1 c1 hc1) _
    have hBpos : 0 < (1 + c2RC R pi c1) ^ ((1 - rho) - 1) :=
      Real.rpow_pos_of_pos (hbase2 c1 hc1) _
    have hgsq_pos : 0 < ((1 + c2RC R pi c1) ^ (1 - rho) - 1) ^ 2 :=
      (sq_nonneg _).lt_of_ne' (pow_ne_zero 2 (hgne c1 hc1))
    apply div_pos _ hgsq_pos
    set f := (1 + c1) ^ (1 - rho) - 1 with hf_def
    set g := (1 + c2RC R pi c1) ^ (1 - rho) - 1 with hg_def
    set A := (1 + c1) ^ ((1 - rho) - 1) with hA_def
    set B := (1 + c2RC R pi c1) ^ ((1 - rho) - 1) with hB_def
    set mu := R * pi / (1 - pi) with hmu_def
    show 0 < (1 - rho) * A * g - f * ((1 - rho) * B * (-mu))
    have hexpand : (1 - rho) * A * g - f * ((1 - rho) * B * (-mu)) =
        (1 - rho) * (A * g + mu * (B * f)) := by ring
    rw [hexpand]
    rcases lt_or_gt_of_ne halpha_ne with hneg | hpos
    · have hf_neg : f < 0 := rpow_sub_one_sign_neg hc1.1 hneg
      have hg_neg : g < 0 := rpow_sub_one_sign_neg (hc2pos c1 hc1) hneg
      have h1 : A * g < 0 := mul_neg_of_pos_of_neg hApos hg_neg
      have h2 : mu * (B * f) < 0 := mul_neg_of_pos_of_neg hmu_pos (mul_neg_of_pos_of_neg hBpos hf_neg)
      have hsum_neg : A * g + mu * (B * f) < 0 := by linarith
      exact mul_pos_of_neg_of_neg hneg hsum_neg
    · have hf_pos : 0 < f := rpow_sub_one_sign_pos hc1.1 hpos
      have hg_pos : 0 < g := rpow_sub_one_sign_pos (hc2pos c1 hc1) hpos
      have h1 : 0 < A * g := mul_pos hApos hg_pos
      have h2 : 0 < mu * (B * f) := mul_pos hmu_pos (mul_pos hBpos hf_pos)
      have hsum_pos : 0 < A * g + mu * (B * f) := by linarith
      exact mul_pos hpos hsum_pos
  have hcont : ContinuousOn (fun c1 => Phi c1 (c2RC R pi c1) rho) (Ioo 0 (1/pi)) :=
    fun c1 hc1 => (hderiv c1 hc1).continuousAt.continuousWithinAt
  apply strictMonoOn_of_deriv_pos hD hcont
  intro c1 hc1
  rw [hIntD] at hc1
  rw [(hderiv c1 hc1).deriv]
  exact hMpos c1 hc1

/-- Proposition 1 / Lemma `lem:phi`, `ρ = 1` (log-utility) case. -/
theorem phi_resource_strictMonoOn_of_eq_one (hpi0 : 0 < pi) (hpi1 : pi < 1) (hR : 1 < R) :
    StrictMonoOn (fun c1 => Phi c1 (c2RC R pi c1) 1) (Ioo 0 (1 / pi)) := by
  have hRpos : 0 < R := by linarith
  have hD : Convex ℝ (Ioo (0:ℝ) (1/pi)) := convex_Ioo _ _
  have hIntD : interior (Ioo (0:ℝ) (1/pi)) = Ioo (0:ℝ) (1/pi) := interior_Ioo
  have hc2pos : ∀ c1 ∈ Ioo (0:ℝ) (1/pi), 0 < c2RC R pi c1 := by
    intro c1 hc1
    obtain ⟨hc1L, hc1U⟩ := hc1
    have hpc1 : pi * c1 < 1 := by
      rw [lt_div_iff₀ hpi0] at hc1U; nlinarith
    have h1pi : 0 < 1 - pi := by linarith
    have hnum : 0 < 1 - pi * c1 := by linarith
    unfold c2RC; positivity
  have hbase1 : ∀ c1 ∈ Ioo (0:ℝ) (1/pi), (0:ℝ) < 1 + c1 := fun c1 hc1 => by linarith [hc1.1]
  have hbase2 : ∀ c1 ∈ Ioo (0:ℝ) (1/pi), (0:ℝ) < 1 + c2RC R pi c1 :=
    fun c1 hc1 => by linarith [hc2pos c1 hc1]
  have hgpos : ∀ c1 ∈ Ioo (0:ℝ) (1/pi), 0 < Real.log (1 + c2RC R pi c1) := by
    intro c1 hc1
    exact Real.log_pos (by linarith [hc2pos c1 hc1])
  have hderiv_f : ∀ c1 ∈ Ioo (0:ℝ) (1/pi),
      HasDerivAt (fun c1 => Real.log (1 + c1)) (1 / (1 + c1)) c1 := by
    intro c1 hc1
    have hbase : HasDerivAt (fun c1 : ℝ => 1 + c1) 1 c1 := (hasDerivAt_id' c1).const_add (1:ℝ)
    simpa using hbase.log (hbase1 c1 hc1).ne'
  have hderiv_g : ∀ c1 ∈ Ioo (0:ℝ) (1/pi),
      HasDerivAt (fun c1 => Real.log (1 + c2RC R pi c1))
        ((-(R * pi / (1 - pi))) / (1 + c2RC R pi c1)) c1 := by
    intro c1 hc1
    have hcomp : HasDerivAt (fun c1 => 1 + c2RC R pi c1) (-(R * pi / (1 - pi))) c1 :=
      (hasDerivAt_c2RC R pi c1).const_add (1:ℝ)
    simpa using hcomp.log (hbase2 c1 hc1).ne'
  have hgne : ∀ c1 ∈ Ioo (0:ℝ) (1/pi), Real.log (1 + c2RC R pi c1) ≠ 0 :=
    fun c1 hc1 => (hgpos c1 hc1).ne'
  have hderiv : ∀ c1 ∈ Ioo (0:ℝ) (1/pi),
      HasDerivAt (fun c1 => Phi c1 (c2RC R pi c1) 1)
        (((1 / (1 + c1)) * Real.log (1 + c2RC R pi c1) -
            Real.log (1 + c1) * ((-(R * pi / (1 - pi))) / (1 + c2RC R pi c1))) /
          Real.log (1 + c2RC R pi c1) ^ 2) c1 := by
    intro c1 hc1
    have hPhi_eq : (fun c1 => Phi c1 (c2RC R pi c1) (1:ℝ)) =
        (fun c1 => Real.log (1 + c1) / Real.log (1 + c2RC R pi c1)) := by
      funext c1; exact Phi_of_eq_one c1 (c2RC R pi c1)
    rw [hPhi_eq]
    exact (hderiv_f c1 hc1).fun_div (hderiv_g c1 hc1) (hgne c1 hc1)
  have hMpos : ∀ c1 ∈ Ioo (0:ℝ) (1/pi),
      0 < ((1 / (1 + c1)) * Real.log (1 + c2RC R pi c1) -
            Real.log (1 + c1) * ((-(R * pi / (1 - pi))) / (1 + c2RC R pi c1))) /
          Real.log (1 + c2RC R pi c1) ^ 2 := by
    intro c1 hc1
    have hgsq_pos : 0 < Real.log (1 + c2RC R pi c1) ^ 2 :=
      (sq_nonneg _).lt_of_ne' (pow_ne_zero 2 (hgne c1 hc1))
    apply div_pos _ hgsq_pos
    have hlogc1_pos : 0 < Real.log (1 + c1) := Real.log_pos (by linarith [hc1.1])
    have hmu_pos : 0 < R * pi / (1 - pi) := by
      have h1pi : 0 < 1 - pi := by linarith
      positivity
    have hterm1 : 0 < (1 / (1 + c1)) * Real.log (1 + c2RC R pi c1) :=
      mul_pos (div_pos one_pos (by linarith [hc1.1])) (hgpos c1 hc1)
    have hterm2 : 0 < Real.log (1 + c1) * (R * pi / (1 - pi) / (1 + c2RC R pi c1)) :=
      mul_pos hlogc1_pos (div_pos hmu_pos (hbase2 c1 hc1))
    have hrw : (-(R * pi / (1 - pi))) / (1 + c2RC R pi c1) =
        -(R * pi / (1 - pi) / (1 + c2RC R pi c1)) := by ring
    rw [hrw, mul_neg, sub_neg_eq_add]
    linarith
  have hcont : ContinuousOn (fun c1 => Phi c1 (c2RC R pi c1) 1) (Ioo 0 (1/pi)) :=
    fun c1 hc1 => (hderiv c1 hc1).continuousAt.continuousWithinAt
  apply strictMonoOn_of_deriv_pos hD hcont
  intro c1 hc1
  rw [hIntD] at hc1
  rw [(hderiv c1 hc1).deriv]
  exact hMpos c1 hc1

/-- **Proposition 1** (`prop:upslope`). Under the Diamond-Dybvig resource constraint and
shifted-CRRA utility, the withdrawal threshold `Φ_shift(c1, c2(c1), ρ)` is strictly
increasing in `c1` for every `ρ > 0`, on the domain where `c2(c1) > 0`. -/
theorem prop_upslope (hpi0 : 0 < pi) (hpi1 : pi < 1) (hR : 1 < R) (hrho0 : 0 < rho) :
    StrictMonoOn (fun c1 => Phi c1 (c2RC R pi c1) rho) (Ioo 0 (1 / pi)) := by
  rcases eq_or_ne rho 1 with h | h
  · subst h; exact phi_resource_strictMonoOn_of_eq_one hpi0 hpi1 hR
  · exact phi_resource_strictMonoOn_of_ne_one hpi0 hpi1 hR hrho0 h

/-! ### Regularity condition (R2): `Φ(c1, c2, ρ) < 1` whenever `c1 < c2`

Section III states this as one of the two regularity conditions needed for existence and
uniqueness of the rational-expectations equilibrium ((R2), used in
`Bankruns.exists_unique_equilibrium_threshold`), and asserts it is "guaranteed by the
resource constraint when `R > 1` and `π < 1`" without giving an explicit proof. We supply
one here, for every `ρ` (both `ρ ≠ 1` and `ρ = 1`), together with the companion fact
`Φ > 0` whenever `c1, c2 > 0`. -/

/-- `(1+x)^α - 1 ≠ 0` restated with the sign spelled out is used repeatedly; here is the
positivity companion `Φ(c1,c2,ρ) > 0` whenever `c1, c2 > 0`, for every `ρ` (numerator and
denominator always share the sign of `1-ρ`, so their ratio is always positive). -/
theorem Phi_pos_of_pos {c1 c2 : ℝ} (hc1 : 0 < c1) (hc2 : 0 < c2) (rho : ℝ) :
    0 < Phi c1 c2 rho := by
  rcases eq_or_ne rho 1 with h | h
  · subst h
    rw [Phi_of_eq_one]
    exact div_pos (Real.log_pos (by linarith)) (Real.log_pos (by linarith))
  · rw [Phi_of_ne_one h]
    have halpha_ne : (1:ℝ) - rho ≠ 0 := sub_ne_zero.mpr (fun he => h he.symm)
    rcases lt_or_gt_of_ne halpha_ne with hα | hα
    · exact div_pos_of_neg_of_neg (rpow_sub_one_sign_neg hc1 hα) (rpow_sub_one_sign_neg hc2 hα)
    · exact div_pos (rpow_sub_one_sign_pos hc1 hα) (rpow_sub_one_sign_pos hc2 hα)

/-- **Regularity condition (R2)**: `Φ(c1, c2, ρ) < 1` whenever `0 < c1 < c2`, for every
risk-aversion parameter `ρ`. -/
theorem Phi_lt_one_of_lt {c1 c2 : ℝ} (hc1 : 0 < c1) (hlt : c1 < c2) (rho : ℝ) :
    Phi c1 c2 rho < 1 := by
  have hc2 : 0 < c2 := hc1.trans hlt
  rcases eq_or_ne rho 1 with h | h
  · subst h
    rw [Phi_of_eq_one]
    have h1 : (0:ℝ) < Real.log (1 + c2) := Real.log_pos (by linarith)
    have h2 : Real.log (1 + c1) < Real.log (1 + c2) :=
      Real.log_lt_log (by linarith) (by linarith)
    rw [div_lt_one h1]
    exact h2
  · rw [Phi_of_ne_one h]
    have halpha_ne : (1:ℝ) - rho ≠ 0 := sub_ne_zero.mpr (fun he => h he.symm)
    have hab : (1:ℝ) + c1 < 1 + c2 := by linarith
    have ha0 : (0:ℝ) ≤ 1 + c1 := by linarith
    rcases lt_or_gt_of_ne halpha_ne with hα | hα
    · -- α < 0: bigger base, negative exponent ⟹ smaller value, via the reciprocal trick
      have hpos_na : (0:ℝ) < -(1 - rho) := by linarith
      have h1 : (1 + c1) ^ (-(1 - rho)) < (1 + c2) ^ (-(1 - rho)) :=
        Real.rpow_lt_rpow ha0 hab hpos_na
      have hxa : (1 + c1) ^ (1 - rho) = ((1 + c1) ^ (-(1 - rho)))⁻¹ := by
        rw [← Real.rpow_neg ha0, neg_neg]
      have hxb : (1 + c2) ^ (1 - rho) = ((1 + c2) ^ (-(1 - rho)))⁻¹ := by
        rw [← Real.rpow_neg (by linarith : (0:ℝ) ≤ 1 + c2), neg_neg]
      have hstep : 1 / (1 + c2) ^ (-(1 - rho)) < 1 / (1 + c1) ^ (-(1 - rho)) :=
        one_div_lt_one_div_of_lt (Real.rpow_pos_of_pos (by linarith : (0:ℝ) < 1 + c1) _) h1
      have hba : (1 + c2) ^ (1 - rho) < (1 + c1) ^ (1 - rho) := by
        rw [hxa, hxb, inv_eq_one_div, inv_eq_one_div]
        exact hstep
      have hdenom_neg : (1 + c2) ^ (1 - rho) - 1 < 0 :=
        rpow_sub_one_sign_neg hc2 hα
      have hnum_gt : (1 + c1) ^ (1 - rho) - 1 > (1 + c2) ^ (1 - rho) - 1 := by linarith
      have hkey : ((1 + c1) ^ (1 - rho) - 1) / ((1 + c2) ^ (1 - rho) - 1) - 1 < 0 := by
        rw [div_sub_one hdenom_neg.ne]
        exact div_neg_of_pos_of_neg (by linarith) hdenom_neg
      linarith
    · -- α > 0: bigger base, positive exponent ⟹ bigger value
      have h1 : (1 + c1) ^ (1 - rho) < (1 + c2) ^ (1 - rho) := Real.rpow_lt_rpow ha0 hab hα
      have hdenom_pos : 0 < (1 + c2) ^ (1 - rho) - 1 := rpow_sub_one_sign_pos hc2 hα
      have hkey : ((1 + c1) ^ (1 - rho) - 1) / ((1 + c2) ^ (1 - rho) - 1) - 1 < 0 := by
        rw [div_sub_one hdenom_pos.ne']
        exact div_neg_of_neg_of_pos (by linarith) hdenom_pos
      linarith

end Bankruns
