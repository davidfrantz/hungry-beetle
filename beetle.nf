#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include { load } from './modules/load.nf'
include { force_get_tiles } from './modules/force.nf'
include { force_analysis_masks } from './modules/force.nf'
include { stats_reference_period } from './modules/reference-statistics.nf'
include { residuals_monitoring_period } from './modules/monitoring-residuals.nf'
include { disturbances_monitoring_period } from './modules/monitoring-disturbances.nf'


/* main workflow
-- do not run directly, use ``feed-beetle.sh`` */
workflow {

  // load input data into channels
  load()
  // | view

  // retrieve processing extent and spatial processing units (tiles)
  tiles = force_get_tiles(
    load.out.aoi, 
    load.out.datacube_definition
  )
  // | view

  // generate or load processing masks for which analyses should be made
  if (params.mask.is_vector) {
    masks = force_analysis_masks(
      load.out.mask,
      load.out.datacube_definition
    )
  } else {
    masks = load.out.mask
  }
  //| view

  combined_input = load.out.datacube
    | combine(masks)
    | combine(tiles)

  // compute statistics (std dev.) in reference period
  stats = combined_input
    | stats_reference_period
    //| view

  // compute residuals in monitoring period
  residuals = combined_input
    | residuals_monitoring_period
    //| view

  // detect disturbances, and do some postprocessing-analysis
  disturbances_monitoring_period(stats, residuals)

}
