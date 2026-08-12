#!/usr/bin/env Rscript

source_path <- "paper.Rnw"
archive_dir <- "archive"
archive_path <- file.path(archive_dir, "legacy_empirical_blocks_20260724.tex")

lines <- readLines(source_path, warn = FALSE)
starts <- which(trimws(lines) == "\\iffalse")
ends <- which(trimws(lines) == "\\fi")

if (length(starts) != 2L || length(ends) != 2L || any(ends <= starts)) {
  stop("Expected exactly two ordered legacy blocks")
}

dir.create(archive_dir, recursive = TRUE, showWarnings = FALSE)
archived <- c(
  "% Legacy empirical blocks extracted from paper.Rnw on 2026-07-24.",
  "% These passages describe superseded simulation designs and are not compiled.",
  ""
)
revised <- character()
cursor <- 1L

for (i in seq_along(starts)) {
  revised <- c(
    revised,
    lines[cursor:(starts[[i]] - 1L)],
    sprintf("%% Legacy empirical block %d archived in %s.", i, archive_path)
  )
  archived <- c(
    archived,
    sprintf("%% ===== Legacy block %d =====", i),
    lines[(starts[[i]] + 1L):(ends[[i]] - 1L)],
    ""
  )
  cursor <- ends[[i]] + 1L
}
revised <- c(revised, lines[cursor:length(lines)])

writeLines(archived, archive_path)
writeLines(revised, source_path)
