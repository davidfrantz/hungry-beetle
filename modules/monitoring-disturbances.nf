include { multijoin } from './defs.nf'
include { force_pyramid } from './force.nf'
include { force_mosaic } from './force.nf'


// detect disturbances, and do some postprocessing-analysis
workflow disturbances_monitoring_period {

  take:
  stats
  residuals
  // stats::     tuple [path higher-level files, tile ID, tile ID (X), tile ID (Y)]
  // residuals:: tuple [path higher-level files, tile ID, tile ID (X), tile ID (Y)]

  main:
  disturbances = multijoin(
    [stats, residuals], 
    [1, 2, 3] 
  ) // join input channels by [tile ID, tile ID (X), tile ID (Y)]
  | disturbance_detection // detect disturbances

  disturbances
  | (force_pyramid & force_mosaic) // compute pyramids and mosaic

  disturbances 
  | disturbance_hist // histograms of disturbance dates (for each tile)
  | map{ it[0] } // select path only
  | collect // collect all results
  | disturbance_hist_merge // merge results (whole AOI)
  | disturbance_report // create report

}

// detect the disturbances
process disturbance_detection {

  label 'rstats'
  label 'multithread'

  input:
  tuple val(tile_ID), val(tile_X), val(tile_Y), path("stats/*"), path("residuals/*")

  output:
  tuple path("${tile_ID}/*"), val(tile_ID), val(tile_X), val(tile_Y)

  publishDir "$params.publish/$params.project", mode: 'copy', overwrite: true, failOnError: true

  """
  mkdir "${tile_ID}"
  disturbance_detection.r \
    "${params.max_cpu}" \
    "stats" \
    "residuals" \
    "${tile_ID}/disturbance_date.tif" \
    "${params.thr_std}" \
    "${params.thr_min}"
  """

}

// compute histograms of the disturbance date
process disturbance_hist {

  label 'rstats'

  input:
  tuple path(disturbance_dates), val(tile_ID), val(tile_X), val(tile_Y)

  output:
  tuple path("${tile_ID}_disturbance_hist.csv"), val(tile_ID), val(tile_X), val(tile_Y)

  """
  mkdir "${tile_ID}"
  histogram.r \
    "${disturbance_dates}" \
    "${tile_ID}_disturbance_hist.csv"
  """

}

// merge the individual histograms
process disturbance_hist_merge {

  label 'rstats'

  input:
  path "hist/*"

  output:
  path "disturbance_hist.csv"

  publishDir "${params.publish}/${params.project}", mode: 'copy', overwrite: true, failOnError: true

  """
  histogram_merge.r \
    "hist" \
    "disturbance_hist.csv"
  """

}

// create a user-friendly report
process disturbance_report {

  label 'rstats'

  input:
  path csv_table

  output:
  path "disturbance_report.html"

  publishDir "${params.publish}/${params.project}", mode: 'copy', overwrite: true, failOnError: true

  """
  disturbance_report.sh \
    "${csv_table}" \
    "disturbance_report.html" \
    "${params.resolution}"
  """

}

