include { multijoin } from './defs.nf'
include { force_pyramid } from './force-core.nf'
include { mosaic }             from './force-glue.nf'

workflow disturbances_monitoring_period {

  take:
  stats
  residuals

  main:
  disturbances = multijoin(
    [stats, residuals], 
    [1, 2, 3] 
  )
  | disturbance_date

  disturbances
  | (force_pyramid & mosaic)

  disturbances 
  | disturbance_hist
  | map{ it[0] } 
  | collect
  | disturbance_hist_collect

}

process disturbance_date {

  label 'rstats'
  label 'multithread'

  input:
  tuple val(tile_ID), val(tile_X), val(tile_Y), path("stats/*"), path("residuals/*")

  output:
  tuple path("$tile_ID/*"), val(tile_ID), val(tile_X), val(tile_Y)

  publishDir "$params.publish/$params.project", mode: 'copy', overwrite: true, failOnError: true

  """
  mkdir "$tile_ID"
  disturbance_date.r "$params.max_cpu" "$tile_ID" "stats" "residuals" "$tile_ID/disturbance_date.tif"
  """

}

process disturbance_hist {

  label 'rstats'

  input:
  tuple path(disturbance_dates), val(tile_ID), val(tile_X), val(tile_Y)

  output:
  tuple path("${tile_ID}_disturbance_hist.csv"), val(tile_ID), val(tile_X), val(tile_Y)

  """
  mkdir "$tile_ID"
  histogram.r "${disturbance_dates}" "${tile_ID}_disturbance_hist.csv"
  """

}

process disturbance_hist_collect {

  label 'rstats'

  input:
  path "hist/*"

  output:
  path "disturbance_hist.csv"

  publishDir "$params.publish/$params.project", mode: 'copy', overwrite: true, failOnError: true

  """
  histogram_collect.r "hist" "disturbance_hist.csv"
  """

}

