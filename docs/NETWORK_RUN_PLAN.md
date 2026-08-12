# Network production run plan

Date: 2026-07-23

## Current execution environment

- Agent count for production estimates: 1,000
- Julia processes: 16 total, normally 15 workers plus the master
- Execution representation: `LargeSparseNetworkModel`
- Output policy: workers return complete results; only the master writes

## Measured whole-model runtimes

Unstressed 1,000-agent models with no endogenous cascade:

| Subjective draws | Approximate seconds per model |
|---:|---:|
| 200 | 0.10 |
| 1,000 | 0.50 |

Stressed small-world models with a clustered ten-agent initial shock:

| Reserve ratio | Draws | Observed range per model |
|---:|---:|---:|
| 0.20 | 200 | 0.62–0.86 seconds |
| 0.20 | 1,000 | 2.61–3.62 seconds |
| 0.30 | 200 | 2.13–3.70 seconds |
| 0.30 | 1,000 | 11.27–18.28 seconds |
| 0.40 | 200 | 1.98–8.14 seconds |
| 0.40 | 1,000 | 12.02–37.22 seconds |

Near-boundary runs with many activation rounds determine the upper runtime
tail. Planning estimates therefore use three seconds per model at 200 draws,
with a six-second contingency case.

## Heuristic parameter dimensions

- 7 deposit specifications
- 16 topology specifications
- 7 insurance specifications
- 3 reserve ratios: proposed `0.20`, `0.30`, `0.40`
- 2 initial-shock sizes: proposed `1` and `10`
- 2 shock-location mechanisms: uniformly random and localized neighborhood
- 3 decision models

The complete Cartesian grid contains:

```text
7 × 16 × 7 × 3 × 2 × 2 × 3 = 28,224 model cells per replication
```

## Stage 0: production runner

Implementation status: complete and smoke-tested.

Before a long sweep:

1. define stable job IDs and seed coordinates;
2. share graphs, deposits, initial shocks, and random streams across the three
   decision models;
3. write atomic result chunks;
4. resume by skipping completed job IDs;
5. keep summary, event, and paired-trial outputs separate;
6. record code revision, Julia version, model types, and execution backend.

Estimated implementation and validation time: one focused development pass.

## Stage 1: subjective-draw convergence

Use 24 deliberately difficult structural scenarios, all three decision models,
30 replications, and draw counts `100`, `200`, `500`, and `1,000`.

```text
24 × 2 × 3 × 30 × 4 = 17,280 model runs
```

Compare paired failure outcomes, total withdrawals, and endogenous withdrawals
against the 1,000-draw reference. Select the smallest depth whose conclusions
are stable.

Estimated wall time on 15 workers: 2–6 hours.

### External launch command

Run from a normal Terminal, outside Codex/Claude Code:

```sh
cd /Users/l25-n05917-res/ResearchCode/BankRunsFinal

julia --project=. scripts/network_experiment.jl \
  init runs/network_20260723 20260723

nohup julia --project=. scripts/network_experiment.jl \
  run convergence runs/network_20260723 \
  --workers 16 \
  > runs/network_20260723/convergence-run.log 2>&1 &

echo $!
```

The printed number is the operating-system process ID. Monitor with:

```sh
tail -f runs/network_20260723/convergence-run.log
```

or:

```sh
julia --project=. scripts/network_experiment.jl \
  status runs/network_20260723
```

If interrupted, rerun only the `nohup` command. Completed chunk job IDs are
detected and skipped.

After completion:

```sh
julia --project=. scripts/network_experiment.jl \
  merge convergence runs/network_20260723

julia --project=. scripts/network_experiment.jl \
  freeze convergence runs/network_20260723
```

Do not run `set-draws` until the merged convergence results have been analyzed.
The run manifest fingerprints package source, the runner, `Project.toml`, and
`Manifest.toml`. Editing any of those after initialization intentionally blocks
resume; Markdown documentation may be updated without changing the fingerprint.

## Stage 2: full-grid coverage audit

Run every Cartesian cell for five replications at the selected draw depth.

```text
28,224 × 5 = 141,120 model runs
```

Purpose:

- catch invalid parameter combinations;
- measure the empirical runtime distribution;
- verify output and resume behavior;
- identify cells near decision or failure boundaries;
- revise the production estimate using actual full-grid timings.

At 200 draws:

- three-second planning mean: about 7.8 compute-hours of wall time;
- six-second contingency mean: about 15.7 compute-hours;
- operational estimate including startup and tail imbalance: 10–20 hours.

## Stage 3A: adaptive high-entropy exploration

Do not assign 20 replications uniformly to every cell. Use the five-replication
coverage audit to fit a mixed-parameter surrogate and allocate additional
replications in batches.

The acquisition score should combine:

1. Bernoulli failure entropy, highest near predicted failure probability 0.5;
2. disagreement among comparative, threshold, and explicit-utility models;
3. posterior uncertainty or low effective replication count;
4. coverage bonuses for underexplored deposit, topology, insurance, reserve,
   shock-size, and shock-location categories;
5. a runtime penalty so a small set of pathological jobs does not consume the
   entire budget.

Because the initial grid is finite and every cell receives five replications,
the first allocator should use direct beta-binomial posterior entropy and
sequential racing over observed cells. TPE becomes useful for a second
off-grid layer: proposing new continuous and hierarchical parameter values
between the heuristic grid points. Topology-specific parameters are
conditional dimensions, as are distribution and insurance parameters. The TPE
objective is the acquisition score, not failure itself.

Recommended adaptive budget: 150,000–250,000 additional model runs after the
coverage audit. At 200 draws this is approximately 8–28 wall-clock hours,
depending on the selected cells' runtime distribution.

Adaptive selection is exploratory. It must not be used directly for unweighted
population-wide averages or final confidence statements.

## Stage 3B: confirmatory sweep

Do not automatically raise the entire Cartesian grid to hundreds of
replications. Select a preregistered subset after the coverage audit, emphasizing:

- boundary reserve ratios;
- representative topology parameters from all four families;
- homogeneous, moderate, and heavy-tailed deposits;
- no, high-quantile, and adaptive insurance;
- cells where decision models disagree;
- cells with intermediate failure probabilities.

Recommended target: 60–100 complete structural configurations and 300–500
replications for each of the three decision models.

Freeze 80 complete configurations selected from the adaptive phase, then
evaluate them with new seeds not observed by the selector. Reserve ratio,
shock size, and shock location are already components of each structural
index; they are not crossed again after selection.

The frozen subset is learned from the completed adaptive outcomes using
posterior failure entropy, disagreement among decision models, posterior
uncertainty, and a runtime penalty. A deterministic greedy diversity bonus
preserves representation across deposit, topology, insurance, reserve,
shock-size, and shock-location categories. The later monotonicity sweep is a
separate prespecified design and is not chosen using observed failure outcomes.

```text
80 complete structural configurations × 3 models × 400 replications
= 96,000 model runs
```

The frozen production selection uses 500 subjective draws. Its adaptive timing
records imply 49.6 worker-hours, or approximately 3.5–5 wall-clock hours with
16 processes after startup and tail imbalance. Four hundred replications give
a worst-case binomial 95% margin of approximately five percentage points for
an individual structural-configuration/model cell.

## Stage 3C: prespecified monotonicity sweep

The learned confirmatory set targets boundaries and decision-model
disagreement, so it is not balanced enough to establish comparative statics.
Run a separate outcome-independent sweep after Stage 3B.

Choose six representative deposit/topology structures before examining the
new outcomes. For each structure and decision model, use matched seeds along
three one-factor paths around a common baseline:

- reserve ratio: `0.10, 0.20, 0.30, 0.40, 0.50`;
- fixed insurance coverage: `0.0, 2.5, 5.0, 10.0`;
- shock size: `1, 5, 10, 20`.

Hold all non-varied parameters fixed within a path. Counting the shared
baseline once gives 11 settings per representative structure. With six
structures, three decision models, and 200 replications, the proposed design
contains 39,600 jobs. Report paired directional contrasts and the fraction of
seed-matched paths satisfying the expected order, not only aggregate means.
The exact structures and hypotheses must be frozen before execution.

The implemented prespecified structures span homogeneous, moderate and
heavy-tailed deposits; small-world, complete, random, and scale-free
topologies; and random and localized shocks. The common baseline is reserve
ratio `0.30`, fixed insurance `5.0`, and shock size `5`. The baseline is stored
once and reused when reporting each path. Within a representative structure
and replication, all 11 settings share scenario and model seeds.

Materialize and freeze the design only after confirmatory results are frozen:

```sh
julia --project=. scripts/network_experiment.jl \
  adopt-monotonicity runs/network_20260723
julia --project=. scripts/network_experiment.jl \
  prepare-monotonicity runs/network_20260723
julia --project=. scripts/network_experiment.jl \
  freeze-monotonicity-design runs/network_20260723
```

The freeze marker records SHA-256 hashes for `design.csv` and
`hypotheses.csv`; execution refuses changed files or a replication count other
than the frozen 200.

## Why not run the full grid at 1,000 draws?

A 50-replication full Cartesian sweep contains 1,411,200 model runs.

- At 200 draws: approximately 4–8 days on 15 workers.
- At 1,000 draws: approximately 20–40 days, with substantial exposure to
  near-boundary runtime tails.

The convergence stage should determine whether this extra computation changes
economic conclusions before it is authorized.

## Storage

Summary output for fewer than one million rows is modest, normally hundreds of
megabytes or less. Agent-event and paired-trial output can be orders of
magnitude larger and should be enabled only for a reproducible diagnostic
subsample, proposed at 1% of jobs plus every failed validation check.

## Recommended execution order

1. Completed: implement and test the resumable production runner.
2. Completed: run Stage 1 and freeze the 500-draw depth.
3. Completed: run and freeze the 141,120-job coverage audit.
4. Completed: run and freeze the 150,000-job adaptive batch.
5. Completed: learn and freeze the 80-cell confirmatory subset.
6. Run, merge, validate, and freeze the 96,000-job Stage 3B.
7. Freeze and run the 39,600-job monotonicity design.
8. Generate tables, uncertainty intervals, and comparative figures.
