#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args) >= 1L) normalizePath(args[[1L]]) else normalizePath(".")
out_dir <- if (length(args) >= 2L) args[[2L]] else
  file.path(root, "output", "final_analysis_seed20260723")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

read_required <- function(path) {
  if (!file.exists(path)) stop("Required input not found: ", path)
  fread(path)
}

dd <- read_required(file.path(root, "output", "dd_core_final_seed20260723.csv"))
bridge <- read_required(file.path(root, "output", "dd_bridge_bounds_seed20260723.csv"))
validation <- read_required(file.path(root, "output", "network_validation_seed20260723.csv"))
confirmatory <- read_required(
  file.path(root, "runs", "network_20260723", "confirmatory", "results.csv")
)
monotonicity <- read_required(
  file.path(root, "runs", "network_20260723", "monotonicity", "results.csv")
)
mono_design <- read_required(
  file.path(root, "runs", "network_20260723", "monotonicity", "design.csv")
)

stopifnot(
  nrow(dd) == 360L,
  nrow(bridge) == 360L,
  nrow(validation) == 1800L,
  nrow(confirmatory) == 96000L,
  nrow(monotonicity) == 39600L,
  uniqueN(confirmatory$job_id) == 96000L,
  uniqueN(monotonicity$job_id) == 39600L
)

rate_ci <- function(events, trials, z = qnorm(0.975)) {
  rate <- events / trials
  se <- sqrt(rate * (1 - rate) / trials)
  list(
    rate = rate,
    lower = pmax(0, rate - z * se),
    upper = pmin(1, rate + z * se)
  )
}

write_table <- function(x, name) {
  setorderv(x, names(x))
  fwrite(x, file.path(out_dir, paste0(name, ".csv")))
}

# 1. Core Diamond-Dybvig simulation findings
dd_summary <- dd[, .(
  parameter_cells = .N,
  mean_failure_rate = mean(failure_rate),
  median_failure_rate = median(failure_rate),
  minimum_failure_rate = min(failure_rate),
  maximum_failure_rate = max(failure_rate)
), by = .(rho, withdrawal_premium, productivity)]
write_table(dd_summary, "dd_core_summary")

dd_premium <- dd[, .(
  mean_failure_rate = mean(failure_rate),
  share_cells_with_failure = mean(failure_rate > 0)
), by = .(rho, withdrawal_premium)]
write_table(dd_premium, "dd_core_by_premium")

p_dd <- ggplot(
  dd,
  aes(withdrawal_probability, failure_rate, color = factor(withdrawal_premium))
) +
  geom_line(aes(group = interaction(rho, productivity, withdrawal_premium)),
            alpha = 0.45) +
  facet_grid(rho ~ productivity, labeller = label_both) +
  scale_color_brewer(palette = "Dark2", name = "Withdrawal\npremium") +
  labs(
    x = "Prior withdrawal probability",
    y = "Holdout bank-failure rate",
    title = "Diamond–Dybvig core: strategic fragility across fundamentals"
  ) +
  theme_minimal(base_size = 11)
ggsave(file.path(out_dir, "figure_dd_core.png"), p_dd, width = 9, height = 6, dpi = 180)

# 2. Bridge-theorem simulations and partial-payment bounds
bridge_wide <- dcast(
  bridge,
  scenario_index + agent_count + deposit + withdrawal_premium + productivity +
    withdrawal_probability + bridge_threshold ~ bound,
  value.var = "withdraw"
)
bound_columns <- setdiff(
  names(bridge_wide),
  c("scenario_index", "agent_count", "deposit", "withdrawal_premium",
    "productivity", "withdrawal_probability", "bridge_threshold")
)
if (length(bound_columns) != 2L) stop("Expected exactly two bridge-bound columns")
bridge_wide[, bounds_agree := get(bound_columns[[1L]]) == get(bound_columns[[2L]])]
bridge_wide[, robust_decision := fifelse(
  bounds_agree,
  fifelse(get(bound_columns[[1L]]), "withdraw", "stay"),
  "bound-sensitive"
)]
bridge_summary <- bridge_wide[, .(scenarios = .N), by = robust_decision]
bridge_summary[, share := scenarios / sum(scenarios)]
write_table(bridge_summary, "bridge_bound_summary")
write_table(bridge_wide, "bridge_scenarios")

p_bridge <- ggplot(
  bridge_wide,
  aes(withdrawal_probability, bridge_threshold, color = robust_decision)
) +
  geom_point(size = 2, alpha = 0.8) +
  facet_grid(withdrawal_premium ~ productivity, labeller = label_both) +
  scale_color_manual(
    values = c("stay" = "#0072B2", "withdraw" = "#D55E00",
               "bound-sensitive" = "#999999"),
    name = "Paired-trial result"
  ) +
  labs(
    x = "Prior withdrawal probability",
    y = "Bridge threshold",
    title = "Finite-agent bridge: withdrawal decisions under both recovery bounds"
  ) +
  theme_minimal(base_size = 11)
ggsave(file.path(out_dir, "figure_bridge_bounds.png"),
       p_bridge, width = 9, height = 6, dpi = 180)

# 3. Network findings
model_summary <- function(d, sample_name, model_column) {
  setnames(copy(d), model_column, "decision_model")[
    , {
      ci <- rate_ci(sum(failed), .N)
      .(
        runs = .N,
        failures = sum(failed),
        failure_rate = ci$rate,
        failure_ci_lower = ci$lower,
        failure_ci_upper = ci$upper,
        mean_endogenous_withdrawals = mean(endogenous_withdrawals),
        probability_endogenous_contagion = mean(endogenous_withdrawals > 0),
        mean_total_withdrawals = mean(total_withdrawals)
      )
    },
    by = decision_model
  ][, sample := sample_name]
}

network_model_summary <- rbindlist(list(
  model_summary(validation, "validation", "model"),
  model_summary(confirmatory, "confirmatory_selected", "decision_model"),
  model_summary(monotonicity, "monotonicity_prespecified", "decision_model")
), use.names = TRUE)
write_table(network_model_summary, "network_model_summary")

paired_rule_comparison <- function(d, sample_name, id_columns, model_column) {
  x <- d[, c(id_columns, model_column, "failed", "endogenous_withdrawals"),
         with = FALSE]
  fail_wide <- dcast(
    x,
    as.formula(paste(paste(id_columns, collapse = " + "), "~", model_column)),
    value.var = "failed"
  )
  endo_wide <- dcast(
    x,
    as.formula(paste(paste(id_columns, collapse = " + "), "~", model_column)),
    value.var = "endogenous_withdrawals"
  )
  required <- c("threshold", "explicit_utility")
  if (!all(required %in% names(fail_wide))) stop("Decision models missing in ", sample_name)
  differences <- as.numeric(fail_wide$threshold) -
    as.numeric(fail_wide$explicit_utility)
  mean_difference <- mean(differences)
  se_difference <- sd(differences) / sqrt(length(differences))
  data.table(
    sample = sample_name,
    matched_scenarios = length(differences),
    threshold_failure_rate = mean(fail_wide$threshold),
    explicit_utility_failure_rate = mean(fail_wide$explicit_utility),
    failure_rate_difference = mean_difference,
    difference_ci_lower = mean_difference - qnorm(0.975) * se_difference,
    difference_ci_upper = mean_difference + qnorm(0.975) * se_difference,
    failure_outcome_agreement = mean(
      fail_wide$threshold == fail_wide$explicit_utility
    ),
    mean_absolute_endogenous_difference = mean(
      abs(endo_wide$threshold - endo_wide$explicit_utility)
    )
  )
}

decision_rule_comparison <- rbindlist(list(
  paired_rule_comparison(validation, "validation", "job_index", "model"),
  paired_rule_comparison(
    confirmatory, "confirmatory_selected",
    c("structural_index", "replication"), "decision_model"
  ),
  paired_rule_comparison(
    monotonicity, "monotonicity_prespecified",
    c("structural_index", "replication"), "decision_model"
  )
))
write_table(decision_rule_comparison, "decision_rule_paired_comparison")

validation_by_reserve <- validation[
  , {
    ci <- rate_ci(sum(failed), .N)
    .(
      runs = .N,
      failure_rate = ci$rate,
      lower = ci$lower,
      upper = ci$upper,
      contagion_probability = mean(endogenous_withdrawals > 0),
      mean_endogenous_withdrawals = mean(endogenous_withdrawals)
    )
  },
  by = .(model, reserve_ratio, initial_count)
]
write_table(validation_by_reserve, "network_validation_by_reserve")

p_network <- ggplot(
  validation_by_reserve,
  aes(reserve_ratio, failure_rate, color = model, group = model)
) +
  geom_ribbon(aes(ymin = lower, ymax = upper, fill = model),
              color = NA, alpha = 0.12) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 2) +
  facet_wrap(~ initial_count, labeller = label_both) +
  labs(
    x = "Reserve ratio",
    y = "Network failure rate",
    title = "Local information and sequential service generate reserve-sensitive runs"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")
ggsave(file.path(out_dir, "figure_network_validation.png"),
       p_network, width = 8, height = 5, dpi = 180)

mono <- merge(
  monotonicity,
  mono_design[, .(structural_index, structure_id, structure_label, path, level)],
  by = "structural_index",
  all.x = TRUE
)
if (anyNA(mono$path)) stop("Monotonicity results do not fully match the design")
mono_path_summary <- mono[
  , .(
    runs = .N,
    failure_rate = mean(failed),
    contagion_probability = mean(endogenous_withdrawals > 0),
    mean_endogenous_withdrawals = mean(endogenous_withdrawals)
  ),
  by = .(structure_id, structure_label, path, level, decision_model)
]
write_table(mono_path_summary, "network_monotonicity_paths")

p_mono <- ggplot(
  mono_path_summary,
  aes(level, failure_rate, color = decision_model, group = decision_model)
) +
  geom_line(
    data = mono_path_summary[path != "baseline"],
    linewidth = 0.7
  ) +
  geom_point(size = 1.6) +
  facet_grid(path ~ structure_label, scales = "free_x") +
  labs(
    x = "Prespecified path level",
    y = "Failure rate",
    title = "Prespecified network comparative statics"
  ) +
  theme_minimal(base_size = 9) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "bottom"
  )
ggsave(file.path(out_dir, "figure_network_monotonicity.png"),
       p_mono, width = 13, height = 8, dpi = 180)

# A short machine-generated factual summary; interpretation remains in the paper.
bridge_counts <- setNames(bridge_summary$scenarios, bridge_summary$robust_decision)
get_count <- function(name) if (name %in% names(bridge_counts)) bridge_counts[[name]] else 0L
comparison_lines <- decision_rule_comparison[
  , sprintf(
    "- %s: threshold %.3f, explicit utility %.3f, difference %.3f (95%% CI %.3f to %.3f), agreement %.3f",
    sample, threshold_failure_rate, explicit_utility_failure_rate,
    failure_rate_difference, difference_ci_lower, difference_ci_upper,
    failure_outcome_agreement
  )
]

report <- c(
  "# Simulation analysis summary",
  "",
  "## Diamond–Dybvig core",
  "",
  sprintf(
    "The core sweep contains %d parameter cells with %s independent holdout realizations per cell.",
    nrow(dd), format(unique(dd$evaluation_realizations), big.mark = ",")
  ),
  "The output tables and figure describe how withdrawal incentives, fundamentals, and risk preferences map into failure risk.",
  "",
  "## Finite-agent bridge",
  "",
  sprintf(
    "The two partial-payment bounds agree in %d of %d scenarios: %d robust withdrawal decisions and %d robust staying decisions; %d scenarios are bound-sensitive.",
    sum(bridge_wide$bounds_agree), nrow(bridge_wide), get_count("withdraw"),
    get_count("stay"), get_count("bound-sensitive")
  ),
  "",
  "## Network decision rules",
  "",
  comparison_lines,
  "",
  "The validation and prespecified monotonicity samples support robustness of threshold versus explicit-utility failure outcomes. The adaptively selected confirmatory sample intentionally concentrates disagreement and boundary cases, so it does not support an unconditional decision-rule irrelevance claim.",
  "",
  "## Local-information mechanism",
  "",
  "Every network model uses local observations, uncertainty about queue position, and sequential service. Endogenous withdrawals and failures occur under all three decision rules, while failure risk falls sharply with reserves in the validation design. This supports the sufficiency claim as a simulation existence-and-robustness result, not as a necessity or identification result."
)
writeLines(report, file.path(out_dir, "analysis_summary.md"))

message("Analysis outputs written to ", normalizePath(out_dir))
