#!/usr/bin/env bash
set -euo pipefail

# Adjust these as needed
DATA_DIR="/Users/l25-n05917-res/ResearchCode/BankRunDataNew2"
JULIA_BIN="/Applications/Julia-1.11.app/Contents/Resources/julia/bin/julia"
PROJECT_DIR="/Users/l25-n05917-res/ResearchCode/BankRuns5"

# Sweep definitions (short, overnight-friendly)
RESERVE_RATIOS=(0.2 0.4)
DEP_QUANTILES=(0.1 0.2 0.3 0.4)
DIST_NAME="LogNormal"
LOGN_MU=1.0
LOGN_SIGMAS=(2.0 3.0)
WS_KS=(6 10 50)
WS_PS=(0.05 0.15)

# Starting seed for parameter generation (incremented each job)
GEN_SEED=1001

for reserve in "${RESERVE_RATIOS[@]}"; do
  for depq in "${DEP_QUANTILES[@]}"; do
    for sigma in "${LOGN_SIGMAS[@]}"; do
      for k in "${WS_KS[@]}"; do
        for p in "${WS_PS[@]}"; do
          echo "Running reserve=$reserve depq=$depq mu=$LOGN_MU sigma=$sigma k=$k p=$p seed=$GEN_SEED"
          "$JULIA_BIN" --project="$PROJECT_DIR" "$PROJECT_DIR/finMain0001.jl" \
            "$DATA_DIR" \
            "$GEN_SEED" \
            "$reserve" \
            "$depq" \
            "$DIST_NAME" \
            "$LOGN_MU" \
            "$sigma" \
            "$k" \
            "$p"
          GEN_SEED=$((GEN_SEED + 1))
        done
      done
    done
  done
done
