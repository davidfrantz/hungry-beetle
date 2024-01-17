#!/usr/bin/env Rscript

# load libraries ####################################################
library(dplyr)


# input #############################################################
args   <- commandArgs(trailingOnly = TRUE)
n_args <- 2

if (length(args) != n_args) {
  c(
    "\nWrong input!",
    "1:path_hist",
    "2:file_output\n"
  ) %>%
  stop()
}

path_inp <- args[1]
path_out <- args[2]

f_inp <- path_inp %>%
  dir(
    pattern = "*.csv$",
    full.names = TRUE
  )

n_inp <- length(f_inp)

if (length(n_inp) == 0) {
  stop("\nNo input detected\n")
}


# main thing ########################################################

hist <- numeric(0)

for (i in 1:n_inp) {

  hist <- rbind(
    hist,
    read.csv(f_inp[i])
  )

}

hist <- hist %>%
  group_by(date) %>%
  summarize_if(is.numeric, sum) %>%
  ungroup()

write.csv(
  hist,
  file = path_out,
  quote = FALSE,
  row.names = FALSE
)
