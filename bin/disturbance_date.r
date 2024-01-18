#!/usr/bin/env Rscript

# load libraries ####################################################
library(terra)
library(dplyr)
library(snowfall)


# input #############################################################
args   <- commandArgs(trailingOnly = TRUE)
n_args <- 6

if (length(args) != n_args) {
  c(
    "\nWrong input!\n",
    " 1: cpus\n",
    " 2: path_stats\n",
    " 3: path_residuals\n",
    " 4: file_output\n",
    " 5: threshold (std dev)\n",
    " 6: threshold (min)\n"
  ) %>%
  stop()
}

cpus     <- args[1] %>% as.numeric()
path_std <- args[2]
path_res <- args[3]
path_out <- args[4]
thr_std  <- args[5] %>% as.numeric()
thr_min  <- args[6] %>% as.numeric()


f_std <- path_std %>%
  dir(
    pattern = "*.tif$",
    full.names = TRUE
  )

f_res <- path_res %>%
  dir(
    pattern = "*.tif$",
    full.names = TRUE
  )

if (length(f_std) != 1) {
  stop("\nToo many input images for stats\n")
}

if (length(f_res) != 1) {
  stop("\nToo many input images for residuals\n")
}


# pixel function ####################################################
detect_disturbance <- function(i, std = NULL, res = NULL,
                                thr_std = NULL, thr_min = NULL) {

  # valid observations
  valid_obs <- res[i, ] %>%
    unlist() %>%
    is.finite() %>%
    which()
  n_valid_obs <- length(valid_obs)

  # we need at least 3 observations
  if (n_valid_obs < 3) return(NA)

  # subset
  val <- res[i, valid_obs]

  # candidates if observations > thresholds
  candidates <- (val > (thr_std * std[i, 1])) & (val > thr_min)

  # we need at least 3 candidates
  if (sum(candidates) < 3) return(NA)

  # extract date
  dates <- candidates %>%
    colnames() %>%
    gsub("_.*", "", .)

  years     <- dates %>%
    substr(1, 4)

  # dates + candidates are tail-padded to ensure that
  # candidates are reset in each year
  dates_padded <- split(dates, years) %>%
    sapply(append, "20990101") %>%
    unlist()

  candidates_padded <- split(candidates, years) %>%
    sapply(append, FALSE) %>%
    unlist()

  n_padded <- length(candidates_padded)

  # to confirm a disturbance, 3 obs > threshold are needed
  confirmed <-
    candidates_padded[1 : (n_padded - 2)] +
    candidates_padded[2 : (n_padded - 1)] +
    candidates_padded[3 : n_padded]

  # we need at least 3 obs > threshold
  if (all(confirmed < 3)) return(NA)

  # first confirmed disturbance
  disturbance <- which(confirmed == 3)[1]

  # extract date
  date <- dates_padded[disturbance] %>%
    strptime("%Y%m%d")

  # continuous date since 1970
  year <- as.integer(format(date, "%Y")) - 1970
  doy  <- as.integer(format(date, "%j"))
  ce   <- (year * 365) + doy

  return(ce)

}


# main thing ########################################################

# open input images
r_std <- rast(f_std)
r_res <- rast(f_res)

# open output image
r_out <- rast(r_std)

# valid pixels
valid <- r_std[] %>%
  is.finite() %>%
  which()
n_valid <- length(valid)

# if pixel is valid, attempt detection, do in parallel
if (n_valid > 0) {

  # subset
  std <- extract(r_std, valid)
  res <- extract(r_res, valid)

  sfInit(
    parallel = TRUE,
    cpus = cpus
  )

  sfLibrary(dplyr)

  disturbance <- sfSapply(
    1:n_valid,
    detect_disturbance,
    std = std,
    res = res,
    thr_std = thr_std,
    thr_min = thr_min
  )

  sfStop()

  r_out[valid] <- disturbance

}


# write output ######################################################
writeRaster(
  r_out,
  filename = path_out,
  datatype = "INT2U",
  gdal = c(
    "INTERLEAVE=BAND",
    "COMPRESS=LZW",
    "PREDICTOR=2",
    "BIGTIFF=YES",
    "TILED=YES"
  ),
  names = "date of disturbance",
  NAflag = 0
)
