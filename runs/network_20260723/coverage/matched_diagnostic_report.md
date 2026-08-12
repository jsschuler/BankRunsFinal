# Matched coverage diagnostic

- Input: `/Users/l25-n05917-res/ResearchCode/BankRunsFinal/runs/network_20260723/coverage/results.csv`
- Coverage jobs: 141120
- Matched scenario/replication groups: 47040
- Pairwise comparative-model contrasts: 94080
- Above-par payment flags: 0

## Main result

The comparative model survived while its comparator failed in 3985 pairwise matches. Of these, 3985 used heterogeneous deposits and 0 used homogeneous deposits.
Across all contrasts, the comparative model made more withdrawals while retaining more vault value in 2271 matches (2.41%).
Within comparator-only failures, that pattern occurred in 2177 of 3985 matches (54.63%).

This pattern means withdrawal counts alone do not explain bank
failure: the identity and insured payment of withdrawing agents
materially change vault depletion. It supports a claim-size
selection mechanism, but does not by itself establish that the
underlying decision rule is economically correct.

## Failure-boundary diagnostic

The comparative model has zero recorded failures in 40320 heterogeneous-deposit runs, but its minimum final vault is 0.000352338.
1731 of those runs finish with less than 1 unit in the vault, and 4157 finish with less than 20.
Because `failed` is defined as `final_vault <= 0`, continuous heterogeneous deposits can leave an arbitrarily small positive residual and still be classified as survival. This exact boundary contributes to the sharp zero-failure result and should be reported alongside near-depletion outcomes.

## Pairwise summary

```text
2×7 DataFrame
 Row │ comparator_model  matched_runs  comparative_only_failures  comparator_only_failures  more_withdrawals_and_more_vault  mean_withdrawal_difference  mean_vault_difference
     │ String            Int64         Int64                      Int64                     Int64                            Float64                     Float64
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ threshold                47040                        133                      2346                             1210                     7.82428               -97.4627
   2 │ explicit_utility         47040                        128                      1639                             1061                     9.25918              -114.637
```

## Deposit and insurance strata

```text
24×10 DataFrame
 Row │ deposit_model      insurance_model  comparator_model  matched_runs  comparative_failure_rate  comparator_failure_rate  comparator_only_failures  more_withdrawals_and_more_vault_rate  mean_withdrawal_difference  mean_vault_difference
     │ String             String           String            Int64         Float64                   Float64                  Int64                     Float64                               Float64                     Float64
─────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ clipped_lognormal  adaptive         explicit_utility          2880                  0.0                    0.0                                0                            0.0                          0.0458333               -2.90433
   2 │ clipped_lognormal  adaptive         threshold                 2880                  0.0                    0.0                                0                            0.0                          0.0395833               -2.51981
   3 │ clipped_lognormal  fixed            explicit_utility          5760                  0.0                    0.0225694                        130                            0.0269097                   12.8198                -197.826
   4 │ clipped_lognormal  fixed            threshold                 5760                  0.0                    0.0611111                        352                            0.0303819                    9.21892               -153.714
   5 │ clipped_lognormal  none             explicit_utility          2880                  0.0                    0.224653                         647                            0.120139                    21.4278                -206.082
   6 │ clipped_lognormal  none             threshold                 2880                  0.0                    0.203819                         587                            0.107639                    25.9972                -255.192
   7 │ clipped_lognormal  quantile         explicit_utility          8640                  0.0                    0.00868056                        75                            0.00983796                   5.27581                -88.0183
   8 │ clipped_lognormal  quantile         threshold                 8640                  0.0                    0.0224537                        194                            0.0109954                    3.82581                -68.1354
   9 │ clipped_pareto     adaptive         explicit_utility          2880                  0.0                    0.0                                0                            0.0                          0.0454861               -2.87953
  10 │ clipped_pareto     adaptive         threshold                 2880                  0.0                    0.0                                0                            0.0                          0.0395833               -2.50334
  11 │ clipped_pareto     fixed            explicit_utility          5760                  0.0                    0.0232639                        134                            0.025                       19.7594                -219.612
  12 │ clipped_pareto     fixed            threshold                 5760                  0.0                    0.0855903                        493                            0.0446181                   11.9236                -142.383
  13 │ clipped_pareto     none             explicit_utility          2880                  0.0                    0.21875                          630                            0.104861                    19.0917                -191.252
  14 │ clipped_pareto     none             threshold                 2880                  0.0                    0.196181                         565                            0.101736                    24.5663                -244.98
  15 │ clipped_pareto     quantile         explicit_utility          8640                  0.0                    0.00266204                        23                            0.00335648                   6.19317                -86.5959
  16 │ clipped_pareto     quantile         threshold                 8640                  0.0                    0.0179398                        155                            0.00925926                   3.98854                -58.6128
  17 │ homogeneous        adaptive         explicit_utility           960                  0.0                    0.0                                0                            0.0                          0.0                      0.0
  18 │ homogeneous        adaptive         threshold                  960                  0.0                    0.0                                0                            0.0                          0.0                      0.0
  19 │ homogeneous        fixed            explicit_utility          1920                  0.131771               0.0927083                          0                            0.0                          9.87552                -98.7552
  20 │ homogeneous        fixed            threshold                 1920                  0.131771               0.0958333                          0                            0.0                          8.98646                -89.8646
  21 │ homogeneous        none             explicit_utility           960                  0.253125               0.197917                           0                            0.0                         13.4208                -134.208
  22 │ homogeneous        none             threshold                  960                  0.253125               0.186458                           0                            0.0                         16.3042                -163.042
  23 │ homogeneous        quantile         explicit_utility          2880                  0.0                    0.0                                0                            0.0                          0.0                      0.0
  24 │ homogeneous        quantile         threshold                 2880                  0.0                    0.0                                0                            0.0                          0.0                      0.0
```

## Near-depletion summary

```text
9×8 DataFrame
 Row │ deposit_model      decision_model    runs   failures  minimum_final_vault  vault_below_1  vault_below_10  vault_below_20
     │ String31           String31          Int64  Int64     Float64              Int64          Int64           Int64
─────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ clipped_lognormal  comparative       20160         0          0.000639569           1116            2084            2092
   2 │ clipped_lognormal  explicit_utility  20160       852          0.0                    870             987             990
   3 │ clipped_lognormal  threshold         20160      1133          0.0                   1133            1133            1133
   4 │ clipped_pareto     comparative       20160         0          0.000352338            615            2063            2065
   5 │ clipped_pareto     explicit_utility  20160       787          0.0                    811             977             977
   6 │ clipped_pareto     threshold         20160      1213          0.0                   1213            1213            1213
   7 │ homogeneous        comparative        6720       496          0.0                    496             496             496
   8 │ homogeneous        explicit_utility   6720       368          0.0                    368             368             368
   9 │ homogeneous        threshold          6720       363          0.0                    363             363             363
```
