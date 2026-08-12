# Diamond--Dybvig simulation audit (2026-07-24)

## Issue 1: scope of the deposit choice

The DD simulation does contain an ex ante deposit-level choice. For
each parameter cell, it searches the common allocation

`deposit = 0, 10, ..., 1000`

and assigns the remainder of the 1,000-unit endowment to outside
storage. This is a planner-style or common allocation choice: every
agent receives the same deposit and outside endowment. It is not a
decentralized model of heterogeneous individual deposit choices. The
formal stochastic withdrawal model conditions on a given deposit
contract, while the simulation adds this common ex ante allocation
search.

Required reporting distinction:

- common ex ante deposit allocation in the simulation;
- no individual deposit-level choice in the formal withdrawal stage.

## Issue 2: zero deposits were classified as bank failure

In the original implementation, `realize_model` initialized the vault
at zero when the candidate deposit was zero and then classified the
state as failed. Consequently, every parameter cell selecting zero
deposits reported a failure rate of one.

In the frozen `dd_core_final_seed20260723.csv` output:

- 255 of 360 cells selected zero deposits and reported 100% failure;
- 23 selected an interior deposit and averaged 19.8% reported failure;
- 82 selected full deposits and averaged 0.36% reported failure.

Economically, a zero-deposit allocation means that the bank is not
formed. It is nonparticipation, not insolvency. The corrected
implementation must:

1. record whether a bank is formed (`bank_formed = optimal_deposit > 0`);
2. treat zero-deposit realizations as nonfailures;
3. report participation separately from failure conditional on bank
   formation;
4. regenerate the DD results before using them in the paper.

The bridge and network simulations do not use this DD allocation
search and are unaffected.

## Corrected rerun

The full 360-cell production grid was rerun with seed `20260723` and
written to:

`output/dd_core_corrected_seed20260723.csv`

Integrity checks:

- 360 rows and 360 unique job indices;
- all `bank_formed` indicators equal `optimal_deposit > 0`;
- selected allocations are identical to the original run;
- all zero-deposit cells now have zero failures.

Corrected allocation outcomes:

- 255 cells select nonparticipation (`optimal_deposit = 0`);
- 23 cells select an interior deposit;
- 82 cells select the full 1,000-unit deposit.

The corrected unconditional failure rates by `(rho, premium)` are:

| rho | premium | participation | unconditional failure | failure conditional on participation |
|---:|---:|---:|---:|---:|
| 1 | 0.50 | 0.317 | 0.0136 | 0.0430 |
| 1 | 0.55 | 0.283 | 0.0045 | 0.0157 |
| 1 | 0.60 | 0.267 | 0.0152 | 0.0570 |
| 0 | 0.50 | 0.317 | 0.0124 | 0.0391 |
| 0 | 0.55 | 0.300 | 0.0203 | 0.0675 |
| 0 | 0.60 | 0.267 | 0.0149 | 0.0560 |

The allocation-search design does not provide a clean numerical test
of the theorem's fixed-allocation premium comparative static.
Allocations are reoptimized separately at each premium, participation
falls with the premium, and aggregate corrected failure is
nonmonotone. A theorem-facing simulation should hold the deposit
allocation fixed across matched premium values (or report a
prespecified full-deposit design) and analyze participation as a
separate ex ante outcome.
