include { multijoin } from './defs.nf'
include { force_finish } from './force.nf'


// detect disturbances, and do some postprocessing-analysis
workflow disturbances_monitoring_period {

  take:
  stats
  residuals
  // stats::     tuple [path higher-level files, tile ID, tile ID (X), tile ID (Y), product]
  // residuals:: tuple [path higher-level files, tile ID, tile ID (X), tile ID (Y), product]

  main:
  disturbances = multijoin(
    [stats, residuals], 
    [1, 2, 3] 
  ) // join input channels by [tile ID, tile ID (X), tile ID (Y)]
  | map{ [it[0], it[1], it[2], it[3], it[5], 'disturbance'] }
  | disturbance_detection // detect disturbances
  | filter_small_disturbances // remove small objects

  years = disturbances
  | disturbance_year // year of disturbance

  disturbances
  | mix(years)
  | force_finish // compute pyramids and mosaic

  disturbances 
  | disturbance_hist // histograms of disturbance dates (for each tile)
  | map{ it[0] } // select path only
  | collect // collect all results
  | disturbance_hist_merge // merge results (whole AOI)
  | disturbance_report // create report

}

// detect the disturbances
process disturbance_detection {

  label 'beetle'

  input:
  tuple val(tile_ID), val(tile_X), val(tile_Y), path("stats/*"), path("residuals/*"), val(product)

  output:
  tuple path("disturbances.tif"), val(tile_ID), val(tile_X), val(tile_Y), val(product), optional: true

  //publishDir "$params.publish/$params.project", 
  //  saveAs: {fn -> "${tile_ID}/${product}/${file(fn).name}"},
  //  mode: 'copy', overwrite: true, failOnError: true
  
  """
  disturbance_detection \
    -s "stats" \
    -r "residuals" \
    -o "disturbances.tif" \
    -d "${params.thr_std}" \
    -m "${params.thr_min}" \
    -e "${params.thr_direction}"
  """

}

process filter_small_disturbances {

  label 'mmu'

  input:
  tuple path(disturbances), val(tile_ID), val(tile_X), val(tile_Y), val(product)

  output:
  tuple path("disturbance_date.tif"), val(tile_ID), val(tile_X), val(tile_Y), val(product)

  publishDir "$params.publish/$params.project", 
    saveAs: {fn -> "${tile_ID}/${product}/${file(fn).name}"},
    mode: 'copy', overwrite: true, failOnError: true

  """
  mmu \
    "${disturbances}" \
    "disturbance_date.tif" \
    "${params.mmu}"
  """

}

// year of the disturbance
process disturbance_year {

  label 'rstats'

  input:
  tuple path(disturbances), val(tile_ID), val(tile_X), val(tile_Y), val(product)

  output:
  tuple path("disturbance_year.tif"), val(tile_ID), val(tile_X), val(tile_Y), val(product)

  publishDir "$params.publish/$params.project", 
    saveAs: {fn -> "${tile_ID}/${product}/${file(fn).name}"},
    mode: 'copy', overwrite: true, failOnError: true
  
  """
  disturbance_year.r \
    "${disturbances}" \
    "disturbance_year.tif" \
  """

}

// compute histograms of the disturbance date
process disturbance_hist {

  label 'rstats'

  input:
  tuple path(disturbance_dates), val(tile_ID), val(tile_X), val(tile_Y), val(product)

  output:
  tuple path("*.csv"), val(tile_ID), val(tile_X), val(tile_Y), val(product), optional: true

  """
  mkdir "${tile_ID}"
  histogram.r \
    "${disturbance_dates}" \
    "${tile_ID}@${product}@hist.csv"
  """

}

// merge the individual histograms
process disturbance_hist_merge {

  label 'rstats'

  input:
  path "hist/*"

  output:
  path "disturbance_hist.csv"

  publishDir "$params.publish/$params.project", 
    mode: 'copy', overwrite: true, failOnError: true
  
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

