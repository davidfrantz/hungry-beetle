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
    " 1: file_input\n",
    " 2: file_output\n",
  ) %>%
  stop()
}

path_inp <- args[1]
path_out <- args[2]


# main thing ########################################################

# open input images
r_inp <- rast(path_inp)

# open output image
r_out <- rast(r_inp)

year <- floor(r_inp[] / 365) + 1970

r_out[] <- year


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
  names = "year of disturbance",
  NAflag = 0
)
