# Initial-condition sensitivity diagnostic

- Model runs: 9000
- Fixed structure/model cells: 180
- Cells with failure outcome flips across shock membership: 165
- Structural realizations with at least one model flip: 59
- Median within-cell withdrawal range: 286.0
- Maximum within-cell withdrawal range: 433

A cell-level outcome flip is the knife-edge estimand: with
the graph, deposits, parameters, and model fixed, changing
only the initially withdrawing agents changes bank failure.

## Cell summary

```text
180×10 DataFrame
 Row │ structural_index  structure_replication  decision_model    shock_trials  failure_rate  outcome_flip  minimum_total_withdrawals  maximum_total_withdrawals  withdrawal_range  withdrawal_sd
     │ Int64             Int64                  String            Int64         Float64       Bool          Int64                      Int64                      Int64             Float64
─────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │                7                      1  comparative                 50          0.72          true                         10                        300               290       130.21
   2 │                7                      1  explicit_utility            50          0.6           true                         10                        300               290       142.07
   3 │                7                      1  threshold                   50          0.6           true                         10                        300               290       142.07
   4 │                7                      2  comparative                 50          0.54          true                         10                        300               290       144.535
   5 │                7                      2  explicit_utility            50          0.46          true                         10                        300               290       144.535
   6 │                7                      2  threshold                   50          0.46          true                         10                        300               290       144.535
   7 │                7                      3  comparative                 50          0.36          true                         10                        300               290       139.2
   8 │                7                      3  explicit_utility            50          0.34          true                         10                        300               290       137.376
   9 │                7                      3  threshold                   50          0.34          true                         10                        300               290       137.376
  10 │               11                      1  comparative                 50          0.1           true                         10                        400               390       116.911
  11 │               11                      1  explicit_utility            50          0.04          true                         10                        400               390        76.4302
  12 │               11                      1  threshold                   50          0.04          true                         10                        400               390        76.4302
  13 │               11                      2  comparative                 50          0.02          true                         10                        400               390        54.6
  14 │               11                      2  explicit_utility            50          0.0          false                         10                         61                51         7.14
  15 │               11                      2  threshold                   50          0.0          false                         10                         61                51         7.14
  16 │               11                      3  comparative                 50          0.06          true                         10                        400               390        92.6199
  17 │               11                      3  explicit_utility            50          0.02          true                         10                        400               390        54.6067
  18 │               11                      3  threshold                   50          0.02          true                         10                        400               390        54.6067
  19 │               12                      1  comparative                 50          0.78          true                         12                        400               388       154.086
  20 │               12                      1  explicit_utility            50          0.32          true                         12                        400               388       171.148
  21 │               12                      1  threshold                   50          0.3           true                         12                        400               388       168.82
  22 │               12                      2  comparative                 50          0.78          true                         14                        400               386       157.441
  23 │               12                      2  explicit_utility            50          0.2           true                         14                        400               386       146.818
  24 │               12                      2  threshold                   50          0.18          true                         14                        400               386       140.934
  25 │               12                      3  comparative                 50          0.84          true                         11                        400               389       139.556
  26 │               12                      3  explicit_utility            50          0.46          true                         11                        400               389       183.413
  27 │               12                      3  threshold                   50          0.44          true                         11                        400               389       182.034
  28 │               19                      1  comparative                 50          0.62          true                         10                        300               290       140.737
  29 │               19                      1  explicit_utility            50          0.56          true                         10                        300               290       143.952
  30 │               19                      1  threshold                   50          0.6           true                         10                        300               290       142.07
  31 │               19                      2  comparative                 50          0.54          true                         10                        300               290       144.535
  32 │               19                      2  explicit_utility            50          0.42          true                         10                        300               290       143.132
  33 │               19                      2  threshold                   50          0.46          true                         10                        300               290       144.535
  34 │               19                      3  comparative                 50          0.58          true                         10                        300               290       143.132
  35 │               19                      3  explicit_utility            50          0.44          true                         10                        300               290       143.952
  36 │               19                      3  threshold                   50          0.56          true                         10                        300               290       143.952
  37 │               91                      1  comparative                 50          0.84          true                         10                        300               290       105.558
  38 │               91                      1  explicit_utility            50          0.56          true                         10                        300               290       143.186
  39 │               91                      1  threshold                   50          0.5           true                         10                        300               290       142.511
  40 │               91                      2  comparative                 50          0.76          true                         10                        300               290       123.783
  41 │               91                      2  explicit_utility            50          0.56          true                         10                        300               290       143.335
  42 │               91                      2  threshold                   50          0.54          true                         10                        300               290       143.28
  43 │               91                      3  comparative                 50          0.82          true                         10                        300               290       110.747
  44 │               91                      3  explicit_utility            50          0.54          true                         10                        300               290       143.593
  45 │               91                      3  threshold                   50          0.52          true                         10                        300               290       143.261
  46 │              103                      1  comparative                 50          0.88          true                         10                        300               290        94.2388
  47 │              103                      1  explicit_utility            50          0.4           true                         10                        300               290       141.617
  48 │              103                      1  threshold                   50          0.44          true                         10                        300               290       142.943
  49 │              103                      2  comparative                 50          0.68          true                         10                        300               290       134.299
  50 │              103                      2  explicit_utility            50          0.32          true                         10                        300               290       134.137
  51 │              103                      2  threshold                   50          0.4           true                         10                        300               290       140.501
  52 │              103                      3  comparative                 50          0.8           true                         10                        300               290       115.604
  53 │              103                      3  explicit_utility            50          0.46          true                         10                        300               290       142.546
  54 │              103                      3  threshold                   50          0.52          true                         10                        300               290       143.366
  55 │              255                      1  comparative                 50          0.68          true                         10                        200               190        88.6305
  56 │              255                      1  explicit_utility            50          0.66          true                         10                        200               190        90.0047
  57 │              255                      1  threshold                   50          0.64          true                         10                        200               190        91.2
  58 │              255                      2  comparative                 50          0.76          true                         10                        200               190        81.1458
  59 │              255                      2  explicit_utility            50          0.74          true                         10                        200               190        83.3405
  60 │              255                      2  threshold                   50          0.74          true                         10                        200               190        83.3405
  61 │              255                      3  comparative                 50          0.64          true                         10                        200               190        91.2
  62 │              255                      3  explicit_utility            50          0.64          true                         10                        200               190        91.2
  63 │              255                      3  threshold                   50          0.62          true                         10                        200               190        92.2234
  64 │              267                      1  comparative                 50          0.58          true                         10                        200               190        93.7761
  65 │              267                      1  explicit_utility            50          0.5           true                         10                        200               190        95.0
  66 │              267                      1  threshold                   50          0.58          true                         10                        200               190        93.7761
  67 │              267                      2  comparative                 50          0.76          true                         10                        200               190        81.1458
  68 │              267                      2  explicit_utility            50          0.7           true                         10                        200               190        87.0689
  69 │              267                      2  threshold                   50          0.74          true                         10                        200               190        83.3405
  70 │              267                      3  comparative                 50          0.86          true                         10                        200               190        65.9275
  71 │              267                      3  explicit_utility            50          0.78          true                         10                        200               190        78.7068
  72 │              267                      3  threshold                   50          0.82          true                         10                        200               190        72.9956
  73 │              351                      1  comparative                 50          0.96          true                         10                        200               190        37.2322
  74 │              351                      1  explicit_utility            50          0.84          true                         10                        200               190        69.6095
  75 │              351                      1  threshold                   50          0.94          true                         10                        200               190        45.1225
  76 │              351                      2  comparative                 50          0.9           true                         10                        200               190        57.0
  77 │              351                      2  explicit_utility            50          0.74          true                         10                        200               190        83.3405
  78 │              351                      2  threshold                   50          0.86          true                         10                        200               190        65.9275
  79 │              351                      3  comparative                 50          0.82          true                         10                        200               190        72.9956
  80 │              351                      3  explicit_utility            50          0.7           true                         10                        200               190        87.0385
  81 │              351                      3  threshold                   50          0.8           true                         10                        200               190        76.0
  82 │              355                      1  comparative                 50          0.08          true                         10                        300               290        78.6635
  83 │              355                      1  explicit_utility            50          0.04          true                         10                        300               290        56.8282
  84 │              355                      1  threshold                   50          0.04          true                         10                        300               290        56.8282
  85 │              355                      2  comparative                 50          0.1           true                         10                        300               290        86.9803
  86 │              355                      2  explicit_utility            50          0.06          true                         10                        300               290        68.8614
  87 │              355                      2  threshold                   50          0.06          true                         10                        300               290        68.8564
  88 │              355                      3  comparative                 50          0.08          true                         10                        300               290        78.6519
  89 │              355                      3  explicit_utility            50          0.04          true                         10                        300               290        56.8203
  90 │              355                      3  threshold                   50          0.06          true                         10                        300               290        68.8614
  91 │              528                      1  comparative                 50          1.0          false                        400                        400                 0         0.0
  92 │              528                      1  explicit_utility            50          0.96          true                         10                        400               390        76.4241
  93 │              528                      1  threshold                   50          0.98          true                         10                        400               390        54.6
  94 │              528                      2  comparative                 50          1.0          false                        400                        400                 0         0.0
  95 │              528                      2  explicit_utility            50          0.96          true                         10                        400               390        76.4241
  96 │              528                      2  threshold                   50          1.0          false                        400                        400                 0         0.0
  97 │              528                      3  comparative                 50          1.0          false                        400                        400                 0         0.0
  98 │              528                      3  explicit_utility            50          1.0          false                        400                        400                 0         0.0
  99 │              528                      3  threshold                   50          1.0          false                        400                        400                 0         0.0
 100 │              680                      1  comparative                 50          0.9           true                         10                        300               290        86.9401
 101 │              680                      1  explicit_utility            50          0.82          true                         10                        300               290       111.287
 102 │              680                      1  threshold                   50          0.7           true                         10                        300               290       132.712
 103 │              680                      2  comparative                 50          0.88          true                         10                        300               290        94.2388
 104 │              680                      2  explicit_utility            50          0.68          true                         10                        300               290       135.191
 105 │              680                      2  threshold                   50          0.62          true                         10                        300               290       140.61
 106 │              680                      3  comparative                 50          0.88          true                         10                        300               290        94.1309
 107 │              680                      3  explicit_utility            50          0.74          true                         10                        300               290       127.103
 108 │              680                      3  threshold                   50          0.68          true                         10                        300               290       135.162
 109 │              758                      1  comparative                 50          0.84          true                          1                        200               199        72.726
 110 │              758                      1  explicit_utility            50          0.34          true                          1                        200               199        92.2152
 111 │              758                      1  threshold                   50          0.34          true                          1                        200               199        92.2152
 112 │              758                      2  comparative                 50          0.78          true                          1                        200               199        82.099
 113 │              758                      2  explicit_utility            50          0.4           true                          1                        200               199        96.4892
 114 │              758                      2  threshold                   50          0.4           true                          1                        200               199        96.4892
 115 │              758                      3  comparative                 50          0.76          true                          1                        200               199        84.4578
 116 │              758                      3  explicit_utility            50          0.16          true                          1                        200               199        71.3003
 117 │              758                      3  threshold                   50          0.14          true                          1                        200               199        67.4257
 118 │              770                      1  comparative                 50          0.86          true                          1                        200               199        68.6063
 119 │              770                      1  explicit_utility            50          0.34          true                          1                        200               199        92.3611
 120 │              770                      1  threshold                   50          0.34          true                          1                        200               199        92.3611
 121 │              770                      2  comparative                 50          0.88          true                          1                        200               199        64.6133
 122 │              770                      2  explicit_utility            50          0.3           true                          1                        200               199        88.7636
 123 │              770                      2  threshold                   50          0.32          true                          1                        200               199        90.5798
 124 │              770                      3  comparative                 50          0.9           true                          1                        200               199        59.6401
 125 │              770                      3  explicit_utility            50          0.16          true                          1                        200               199        71.5916
 126 │              770                      3  threshold                   50          0.16          true                          1                        200               199        71.5916
 127 │             1009                      1  comparative                 50          0.74          true                          1                        200               199        86.2543
 128 │             1009                      1  explicit_utility            50          0.48          true                          1                        200               199        98.0764
 129 │             1009                      1  threshold                   50          0.48          true                          1                        200               199        98.0764
 130 │             1009                      2  comparative                 50          0.74          true                          1                        200               199        86.0607
 131 │             1009                      2  explicit_utility            50          0.46          true                          1                        200               199        97.6254
 132 │             1009                      2  threshold                   50          0.46          true                          1                        200               199        97.6254
 133 │             1009                      3  comparative                 50          0.74          true                          1                        200               199        86.2316
 134 │             1009                      3  explicit_utility            50          0.38          true                          1                        200               199        94.9572
 135 │             1009                      3  threshold                   50          0.3           true                          1                        200               199        88.9182
 136 │             1016                      1  comparative                 50          0.94          true                         34                        300               266        62.6187
 137 │             1016                      1  explicit_utility            50          0.68          true                         16                        300               284       127.839
 138 │             1016                      1  threshold                   50          0.52          true                         16                        300               284       133.83
 139 │             1016                      2  comparative                 50          0.94          true                         27                        300               273        62.0192
 140 │             1016                      2  explicit_utility            50          0.6           true                         16                        300               284       132.914
 141 │             1016                      2  threshold                   50          0.44          true                         16                        300               284       133.044
 142 │             1016                      3  comparative                 50          0.94          true                         34                        300               266        62.8556
 143 │             1016                      3  explicit_utility            50          0.68          true                         14                        300               286       127.174
 144 │             1016                      3  threshold                   50          0.48          true                         14                        300               286       133.655
 145 │             1022                      1  comparative                 50          0.72          true                          1                        200               199        88.5558
 146 │             1022                      1  explicit_utility            50          0.26          true                          1                        200               199        85.4298
 147 │             1022                      1  threshold                   50          0.26          true                          1                        200               199        85.4298
 148 │             1022                      2  comparative                 50          0.76          true                          1                        200               199        84.1789
 149 │             1022                      2  explicit_utility            50          0.14          true                          1                        200               199        67.7399
 150 │             1022                      2  threshold                   50          0.18          true                          1                        200               199        75.2264
 151 │             1022                      3  comparative                 50          0.7           true                          1                        200               199        89.9912
 152 │             1022                      3  explicit_utility            50          0.26          true                          1                        200               199        84.2406
 153 │             1022                      3  threshold                   50          0.3           true                          1                        200               199        88.4129
 154 │             1192                      1  comparative                 50          0.32          true                         10                        200               190        85.845
 155 │             1192                      1  explicit_utility            50          0.02          true                         10                        200               190        26.4694
 156 │             1192                      1  threshold                   50          0.02          true                         10                        200               190        26.3135
 157 │             1192                      2  comparative                 50          0.42          true                         10                        200               190        91.0264
 158 │             1192                      2  explicit_utility            50          0.02          true                         10                        200               190        26.3487
 159 │             1192                      2  threshold                   50          0.02          true                         10                        200               190        26.1723
 160 │             1192                      3  comparative                 50          0.4           true                         10                        200               190        89.5795
 161 │             1192                      3  explicit_utility            50          0.04          true                         10                        200               190        36.7354
 162 │             1192                      3  threshold                   50          0.04          true                         10                        200               190        36.5508
 163 │             7236                      1  comparative                 50          0.0          false                         10                        429               419        57.0969
 164 │             7236                      1  explicit_utility            50          0.96          true                         10                        431               421        78.5067
 165 │             7236                      1  threshold                   50          0.96          true                         10                        425               415        78.1812
 166 │             7236                      2  comparative                 50          0.0          false                        357                        425                68        15.689
 167 │             7236                      2  explicit_utility            50          1.0          false                        365                        436                71        17.0347
 168 │             7236                      2  threshold                   50          0.94          true                         10                        431               421        94.097
 169 │             7236                      3  comparative                 50          0.0          false                         10                        434               424        57.3403
 170 │             7236                      3  explicit_utility            50          0.94          true                         10                        432               422        94.4267
 171 │             7236                      3  threshold                   50          0.92          true                         10                        443               433       107.26
 172 │             7320                      1  comparative                 50          0.0          false                         10                        417               407       149.51
 173 │             7320                      1  explicit_utility            50          0.56          true                         10                        418               408       191.747
 174 │             7320                      1  threshold                   50          0.46          true                         10                        421               411       193.068
 175 │             7320                      2  comparative                 50          0.0          false                         10                        421               411       156.353
 176 │             7320                      2  explicit_utility            50          0.68          true                         10                        429               419       181.246
 177 │             7320                      2  threshold                   50          0.52          true                         10                        416               406       191.783
 178 │             7320                      3  comparative                 50          0.0          false                         10                        430               420        92.9962
 179 │             7320                      3  explicit_utility            50          0.66          true                         10                        433               423       182.382
 180 │             7320                      3  threshold                   50          0.48          true                         10                        427               417       191.863
```
