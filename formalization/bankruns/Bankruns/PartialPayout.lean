/-
Formalization of Remark `rem:partialpayout` ("Partial payout and the large-K limit"),
Appendix A of Schuler, "Deposits Are Not Options".

With finitely many agents, exactly one agent (the last one served before vault exhaustion)
may receive a partial payment `v ∈ (0, c1)` rather than the failure payoff `0`. This remark
bounds the resulting perturbation to the withdrawal threshold `Φ_shift` by `O(1/K)`.
-/
import Mathlib

open Real

noncomputable section

namespace Bankruns

/-- The finite-`K` withdrawal threshold that blends the ordinary failure payoff `0` (with
probability `1 - 1/K`) and the partial payoff `v` (with probability `1/K`), as in the
paper's `Φ_partial = (1 - 1/K) Φ_shift + (1/K) Φ_v`. -/
def PhiPartial (K : ℕ) (PhiShift PhiV : ℝ) : ℝ :=
  (1 - 1 / (K : ℝ)) * PhiShift + (1 / (K : ℝ)) * PhiV

/-- **Remark `rem:partialpayout`**: for any `K ≥ 1`, if `0 ≤ Φ_v ≤ Φ_shift`, the finite-`K`
correction to the withdrawal threshold satisfies `|Φ_partial - Φ_shift| ≤ Φ_shift / K`, an
`O(1/K)` perturbation. -/
theorem abs_PhiPartial_sub_PhiShift_le (K : ℕ) (hK : 1 ≤ K) (PhiShift PhiV : ℝ)
    (hPhiV_nonneg : 0 ≤ PhiV) (hPhiV_le : PhiV ≤ PhiShift) :
    |PhiPartial K PhiShift PhiV - PhiShift| ≤ PhiShift / K := by
  have hKpos : (0:ℝ) < (K:ℝ) := by exact_mod_cast hK
  have heq : PhiPartial K PhiShift PhiV - PhiShift = (PhiV - PhiShift) / (K:ℝ) := by
    unfold PhiPartial; field_simp; ring
  rw [heq, abs_div, abs_of_pos hKpos, abs_of_nonpos (by linarith : PhiV - PhiShift ≤ 0)]
  gcongr
  linarith

/-- The bound is strictly below `1/K` whenever `Φ_shift < 1` (regularity condition (R2)):
the finite-`K` correction vanishes as `K → ∞` at rate strictly better than `1/K`. -/
theorem abs_PhiPartial_sub_PhiShift_lt (K : ℕ) (hK : 1 ≤ K) (PhiShift PhiV : ℝ)
    (hPhiV_nonneg : 0 ≤ PhiV) (hPhiV_le : PhiV ≤ PhiShift) (hPhi_lt_one : PhiShift < 1) :
    |PhiPartial K PhiShift PhiV - PhiShift| < 1 / K := by
  have hKpos : (0:ℝ) < (K:ℝ) := by exact_mod_cast hK
  have h1 := abs_PhiPartial_sub_PhiShift_le K hK PhiShift PhiV hPhiV_nonneg hPhiV_le
  have h2 : PhiShift / (K:ℝ) < 1 / (K:ℝ) := by gcongr
  exact lt_of_le_of_lt h1 h2

end Bankruns
