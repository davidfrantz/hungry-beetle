#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include { load } from './modules/load.nf'
include { get_tiles } from './modules/force-glue.nf'
include { analysis_masks } from './modules/force-glue.nf'
include { stats_reference_period } from './modules/reference-statistics.nf'
include { residuals_monitoring_period } from './modules/monitoring-residuals.nf'
include { disturbances_monitoring_period } from './modules/monitoring-disturbances.nf'

workflow {

  load()
  
  //load.out.datacube.view()
  //load.out.datacube_definition.view()
  
  tiles = get_tiles(
    load.out.aoi, 
    load.out.datacube_definition
  )

  masks = analysis_masks(
    load.out.mask,
    load.out.datacube_definition
  )
  //| view

  stats = 
    load.out.datacube
    | combine(masks)
    | combine(tiles)
    | stats_reference_period
    //| view

  residuals = 
    load.out.datacube
    | combine(masks)
    | combine(tiles)
    | residuals_monitoring_period
    //| view


  disturbances_monitoring_period(stats, residuals)

}

