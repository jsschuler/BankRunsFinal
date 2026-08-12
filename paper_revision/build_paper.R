#!/usr/bin/env Rscript

root <- normalizePath(dirname(sub("^--file=", "", grep(
  "^--file=", commandArgs(trailingOnly = FALSE), value = TRUE
)[1L])))
setwd(root)

knitr::knit("paper.Rnw", "paper.tex")

run <- function(command, args) {
  status <- system2(command, args)
  if (!identical(status, 0L)) {
    stop(command, " failed with exit status ", status)
  }
}

latex_args <- c("-interaction=nonstopmode", "-halt-on-error", "paper.tex")
run("pdflatex", latex_args)
run("bibtex", "paper")
run("pdflatex", latex_args)
run("pdflatex", latex_args)

message("Wrote ", normalizePath("paper.pdf"))
