# Revision Tasks — "Deposits Are Not Options"

Derived from a self-refereeing pass on the July 2026 draft. Items are text-only unless noted.

## 1. VII.B — Scope declaration on liquidation timescale
Add a short paragraph stating that the network model assumes no within-run-window liquidation
technology: withdrawals resolve faster than long-asset conversion, which is the empirically
relevant regime for digitally intermediated runs (SVB). Note that the reserve ratio `r` is best
read as "resources available on the fast timescale," and that the run margin should close as the
withdrawal/conversion timescale separation collapses — consistent with the existing reserve-ratio
sweeps. Connect to BTFP as a policy response that supplies par-value conversion on the fast
timescale, which the canonical DD insurance prescription does not directly address.
No new model machinery required.

## 2. III.A — Correct the "not a choice variable" error; report the option-driven participation result
- Strike/replace the sentence stating the deposit level is not a choice variable — it is, via the
  allocation search. Document explicitly what the allocation search optimizes over (including
  participation).
- In Section IV, report that agents choose maximum deposits even in high-failure cells, driven by
  the option structure at large ε. Frame this as revealed-preference evidence that participation
  holds through the run-option channel itself, not (only) through the insurance channel DD's
  planner intended.

## 3. New simulation — Small-ε arm of the DD core
Add a DD core arm at ε ∈ {0.01, 0.02, 0.05, 0.1} (limit at ε = 0 handled analytically, not
simulated — participation is degenerate there). Report two things from this arm:
- Run-probability channel: does the withdrawal threshold / failure rate stay near its
  zero-premium limit at realistic ε, including near the transition region identified in Figure 1?
- Participation channel: does the option-driven maximum-deposit result from Section IV persist,
  weaken, or reverse as ε → 0?

## 4. New paragraph — Contracts as institutional givens
Add a paragraph (Section III or IV) framing the DD core as studying behavior under a given
contract, not asserting planner-optimality of the simulated premia under the shifted-CRRA
preferences used. Cite the endogenous-participation result from Item 2 as support: agents are
shown to accept the contract at the simulated premia, which is evidence for demand-side viability
independent of whether a planner would choose these terms under RRA < 1.

## 5. Shifted-CRRA fixes (text only)
- III.A: remove/correct the claim that results "hold under either [shifted or unshifted]
  specification" — false for ρ ≥ 1, where unshifted CRRA gives u(0) = −∞ and the withdrawal
  condition degenerates.
- V.B: name the shift constant explicitly as a third calibration axis for p*(ρ, R), alongside ρ
  and R — not merely implied by the existing "calibration dependent" language.

## 6. VII.B/VII.D — Bias/variance-as-feature sentence
Add a sentence stating that agents cannot separate local-sample bias from variance in their
withdrawal-rate estimate, because doing so would require exactly the global information the model
assumes is unavailable. This reframes network degree k as an information-completeness parameter
rather than a pure variance-reduction knob, and preempts the objection that the k-comparative-static
is a naivety artifact.

## 7. Literature additions
- **Iyer and Puri (2012, AER)** — depositor networks and run participation (empirical). Cite near
  Cookson et al.
- **Jacklin (1987)** — demand deposits, trading restrictions, and risk sharing. Cite near
  Green-Lin / Peck-Shell in the DD-extensions paragraph.
- **Ennis and Keister** (bank runs without commitment; partial suspension of convertibility) — cite
  near Peck-Shell, in support of the Section IX.C policy discussion.
- **He and Manela (2016, JF)** — rumor-based runs / information acquisition. Cite near
  Chari-Jagannathan; add a short sentence distinguishing their information-acquisition mechanism
  from this paper's network-topology/local-sampling mechanism.
- **Angeletos and Werning (2006, AER)** — soften the claim that "global games have no analogue to
  information-architecture interventions" (appears in Introduction and IX.A). Correct framing:
  global games' policy margin operates through signal precision/publicity; this paper's margin
  operates through signal observability, topology, and timing — a related but distinct lever, not
  an absent literature.

## 8. IX.C — Engage the 2023 MMF reform reversal
Acknowledge that the SEC's 2023 MMF reforms replaced the discretionary gates/liquidity-fee
framework with mandatory swing pricing, motivated by evidence that discretionary
threshold-triggered gates caused anticipatory/preemptive runs in March 2020 (redemptions ahead of
the 30% weekly-liquid-assets trigger). Distinguish this from the paper's own batching proposal:
- Discretionary threshold gates add a new observable signal (proximity to the trigger) that can
  itself seed a cascade.
- The paper's universal, pre-announced, simultaneous batching removes signals rather than adding
  one, since it does not depend on a state variable agents can watch approach.

---

*Item 3 requires new simulation runs; all other items are text-only revisions to the existing
draft.*
