/-
Formalization of Remark `rem:partialconn` ("Extension to partial connectivity"),
Appendix A of Schuler, "Deposits Are Not Options".

The paper's cascade-dynamics strategy map `T0`, evaluated on the finite lattice of
withdrawal configurations `Fin K → Bool` (`false` = still banking, `true` = withdrawn),
is isotone under the stated restrictions (no sampling error, fixed bank state, monotone
local-loss signal). This file instantiates Mathlib's Knaster-Tarski fixed-point theorem
(`Mathlib.Order.FixedPoints`, via `OrderHom.lfp` / `OrderHom.gfp`) at that specific
lattice, and proves the paper's two boundary conditions ("the exogenous-only signal lies
below the cutoff" and "the all-neighbors-withdrawn signal lies above it") force the least
and greatest fixed points to be the all-stay and all-withdraw configurations respectively,
hence distinct low- and high-withdrawal rest points whenever `K ≥ 1`.
-/
import Mathlib

open Set

noncomputable section

namespace Bankruns

variable {K : ℕ}

/-- Knaster-Tarski at the withdrawal-configuration lattice: for any isotone strategy map
`T0`, the least and greatest fixed points exist (Mathlib's `OrderHom.lfp` / `OrderHom.gfp`)
and satisfy `T0.lfp ≤ T0.gfp`. -/
theorem tarski_lfp_le_gfp (T0 : (Fin K → Bool) →o (Fin K → Bool)) :
    T0.lfp ≤ T0.gfp :=
  T0.lfp_le_gfp

theorem tarski_lfp_isFixedPt (T0 : (Fin K → Bool) →o (Fin K → Bool)) :
    T0 T0.lfp = T0.lfp := T0.map_lfp

theorem tarski_gfp_isFixedPt (T0 : (Fin K → Bool) →o (Fin K → Bool)) :
    T0 T0.gfp = T0.gfp := T0.map_gfp

/-- If the all-stay configuration `⊥` (only the exogenous shock, no endogenous
withdrawals) is itself a fixed point of the cascade map -- the paper's condition that
"the exogenous-only signal lies below the cutoff" -- then it IS the least fixed point:
no lower rest point exists. -/
theorem tarski_lfp_eq_bot {T0 : (Fin K → Bool) →o (Fin K → Bool)} (h : T0 ⊥ = ⊥) :
    T0.lfp = ⊥ :=
  le_antisymm (T0.lfp_le h.le) bot_le

/-- If the all-withdraw configuration `⊤` is itself a fixed point of the cascade map --
the paper's condition that "the all-neighbors-withdrawn signal lies above the cutoff" --
then it IS the greatest fixed point. -/
theorem tarski_gfp_eq_top {T0 : (Fin K → Bool) →o (Fin K → Bool)} (h : T0 ⊤ = ⊤) :
    T0.gfp = ⊤ :=
  le_antisymm le_top (T0.le_gfp h.ge)

/-- **Remark `rem:partialconn`, full statement**: under the paper's two boundary
conditions and `K ≥ 1`, the least and greatest fixed points are DISTINCT -- the cascade
dynamics admit both a low-withdrawal and a high-withdrawal rest point, exactly as the
Tarski lattice argument in the paper claims. -/
theorem tarski_lfp_ne_gfp (hK : 0 < K) {T0 : (Fin K → Bool) →o (Fin K → Bool)}
    (hbot : T0 ⊥ = ⊥) (htop : T0 ⊤ = ⊤) : T0.lfp ≠ T0.gfp := by
  rw [tarski_lfp_eq_bot hbot, tarski_gfp_eq_top htop]
  intro h
  have h0 : (⊥ : Fin K → Bool) ⟨0, hK⟩ = (⊤ : Fin K → Bool) ⟨0, hK⟩ := congrFun h ⟨0, hK⟩
  simp at h0

end Bankruns
