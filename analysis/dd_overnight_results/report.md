# Expanded Diamond--Dybvig experiment: analysis report

## Integrity

All three panels have the expected row counts (41600 fixed, 6400 main allocation, and 1440 shift allocation) and unique job identifiers.

## Fixed full-deposit experiment

- At zero premium, 5200 cells produce 0 failures; the maximum estimated failure rate is 0.000.
- At withdrawal probability one, zero premium has failure probability 0.000 and every positive premium has minimum failure probability 1.000.
- Across 5200 matched premium paths, 9 have a failure-rate drop exceeding one percentage point and 6 exceed two points.
- Averaged over the grid, failure rises from 0.060 at a 0.5 percent premium to 0.677 at a 50 percent premium.
- Across 10400 matched productivity paths, 0 have a failure increase exceeding one percentage point as productivity rises; the mean step change is -0.0314.

## Common allocation search

- At zero premium, participation by rho is: rho=0: 0.980; rho=0.5: 0.980; rho=1: 0.980; rho=2: 0.975.
- The zero-premium nonparticipation cells are concentrated at withdrawal probability one, where outside storage and par withdrawal are payoff-equivalent; they should be described as tie outcomes, not rejection of banking.
- Across all main-allocation cells, overall participation is 0.789 and full deposit is selected in 0.652 of cells.
- Participation falls from 0.979 at zero premium to 0.330 at a 50 percent premium, while the mean selected deposit falls from 960.4 to 317.1.
- Among participating cells with at least 10 percent failure, there are 142 cells; the overall deposit range is 10 to 1000.
- Deposit choice is not monotone in premium: 22 of 800 matched paths contain an increase and 580 contain a decrease.

## Shift sensitivity

- Across the common four-shift comparison, exact deposit agreement ranges from 0.850 to 1.000 across rho-premium groups.
- Exact participation agreement ranges from 1.000 to 1.000; the maximum within-cell deposit range is 100.

## Interpretation

The fixed-contract results support the intended Diamond--Dybvig comparative static: zero contractual premium is exactly serviceable at full deposit, while positive premia create a liquidity boundary that moves inward on average as the premium rises. The nine material local premium reversals are concentrated near the high-withdrawal boundary and large utility shift, so the result should be stated as an aggregate and boundary comparative static rather than a pointwise theorem about this finite simulation.

The allocation search answers a different question. Participation and selected deposits generally decline as the premium rises, but are not pointwise monotone because agents jointly trade outside storage, early-payment option value, late returns, and run exposure. High-failure participating cells do not generally select the maximum deposit.

The CRRA shift changes the nonlinear utility calculation, but its empirical influence in the targeted allocation comparison is modest: participation is identical across all four shifts, and at least 85 percent of deposits agree exactly in every rho-premium group. Deposit differences are largest for rho=2 and reach 100 units in one cell. The paper should therefore distinguish mathematical non-equivalence from numerical robustness in this calibration.

