#!/usr/bin/env Rscript

# load libraries ####################################################
library(terra)
library(dplyr)


# input #############################################################
args   <- commandArgs(trailingOnly = TRUE)
n_args <- 2

if (length(args) != n_args) {
  c(
    "\nWrong input!\n",
    " 1: path_dates\n",
    " 2: file_output\n"
  ) %>%
  stop()
}

path_inp <- args[1]
path_out <- args[2]


# main thing ########################################################

# open input images
r_inp <- rast(path_inp)

# valid pixels
valid <- r_inp[] %>%
  is.finite() %>%
  which()
n_valid <- length(valid)

# if pixel is valid, attempt detection, do in parallel
if (n_valid > 0) {

  # subset
  tab <- extract(r_inp, valid) %>% 
    table()

  ce <- tab %>%
    names() %>%
    as.numeric()

  year <- ce %>%
    `/`(365) %>%
    floor()

  doy <- ce - year*365

  date <- paste0(year+1970, doy) %>%
    strptime("%Y%j") %>%
    format("%Y-%m-%d")

  hist <- cbind(date = date, count = tab)

  write.csv(
    hist,
    file = path_out,
    quote = FALSE,
    row.names = FALSE
  )

}
