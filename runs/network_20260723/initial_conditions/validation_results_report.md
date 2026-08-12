# Initial-condition sensitivity diagnostic

- Model runs: 6
- Fixed structure/model cells: 3
- Cells with failure outcome flips across shock membership: 0
- Structural realizations with at least one model flip: 0
- Median within-cell withdrawal range: 0.0
- Maximum within-cell withdrawal range: 0

A cell-level outcome flip is the knife-edge estimand: with
the graph, deposits, parameters, and model fixed, changing
only the initially withdrawing agents changes bank failure.

## Cell summary

```text
3×10 DataFrame
 Row │ structural_index  structure_replication  decision_model    shock_trials  failure_rate  outcome_flip  minimum_total_withdrawals  maximum_total_withdrawals  withdrawal_range  withdrawal_sd
     │ Int64             Int64                  String            Int64         Float64       Bool          Int64                      Int64                      Int64             Float64
─────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │               12                      1  comparative                  2           1.0         false                        400                        400                 0            0.0
   2 │               12                      1  explicit_utility             2           1.0         false                        400                        400                 0            0.0
   3 │               12                      1  threshold                    2           1.0         false                        400                        400                 0            0.0
```
