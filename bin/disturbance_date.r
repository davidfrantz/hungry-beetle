#!/usr/bin/env Rscript

# load libraries ####################################################
library(terra)
library(dplyr)
library(snowfall)


# input #############################################################
args   <- commandArgs(trailingOnly = TRUE)
n_args <- 5

if (length(args) != n_args) {
  c(
    "\nWrong input!",
    "1:cpus",
    "2:Tile_ID",
    "3:path_stats",
    "4:path_residuals",
    "5:file_output\n"
  ) %>%
  stop()
}

cpus     <- args[1]
tile_ID  <- args[2]
path_std <- args[3]
path_res <- args[4]
path_out <- args[5]

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
detect_disturbance <- function(i, std = NULL, res = NULL) {

  # valid observations
  valid_obs <- res[i,] %>%
    unlist() %>%
    is.finite() %>%
    which()
  n_valid_obs <- length(valid_obs)

  # we need at least 3 obs
  if (n_valid_obs < 3) return(NA)

  # subset
  val <- res[i,valid_obs]

  # obs > threshold
  candidates <- val > 3*std[i,1]

  # to confirm a disturbance, 3 obs > threshold are needed
  confirmed <-
    candidates[1:(n_valid_obs-2)] +
    candidates[2:(n_valid_obs-1)] +
    candidates[3:n_valid_obs]

  # we need at least 3 obs > threshold
  if (all(confirmed < 3)) return(NA)

  # first confirmed disturbance
  disturbance <- which(confirmed == 3)[1]

  # extract date
  date <- colnames(candidates)[disturbance] %>%
    gsub("_.*", "", .) %>%
    strptime("%Y%m%d")

  # continuous date since 1970
  year <- as.integer(format(date, "%Y")) - 1970
  doy  <- as.integer(format(date, "%j"))
  ce   <- year*365 + doy

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
    res = res
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
