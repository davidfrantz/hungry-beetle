include { force_parameter } from './force.nf'
include { force_higher_level } from './force.nf'
include { force_pyramid } from './force.nf'


// compute residuals in monitoring period
workflow residuals_monitoring_period {

  take:
  datacube_tile
  // tuple path datacube, path masks, tile ID, tile ID (X), tile ID (Y)

  main:
  residuals = force_parameter('TSA')  // create parameter file
  | combine(datacube_tile)   // add parameter file to input tuple
  | fill_parameter_residuals // fill out the parameter file
  | force_higher_level       // run higher level processing

  residuals
  | force_pyramid // compute pyramids
  /* Note: mosaic not possible as residual product is not guaranteed to 
  -- have the same bands in each tile */

  emit:
  residuals

}

// fill out the paramater file
// note: input file is copied to keep cache alive
process fill_parameter_residuals {

  input:
  tuple path(parfile), path(datacube), path(maskdir), val(tile_ID), val(tile_X), val(tile_Y)

  output:
  tuple path("filled_${parfile}"), path(datacube), path(maskdir), val(tile_ID), val(tile_X), val(tile_Y)

  """
  cp "$parfile" "filled_${parfile}"
  sed -i "/^DIR_LOWER /c\\DIR_LOWER = ${datacube}" "filled_${parfile}"
  sed -i "/^DIR_HIGHER /c\\DIR_HIGHER = ." "filled_${parfile}"
  sed -i "/^DIR_PROVENANCE /c\\DIR_PROVENANCE = ." "filled_${parfile}"
  sed -i "/^DIR_MASK /c\\DIR_MASK = ${maskdir}" "filled_${parfile}"
  sed -i "/^BASE_MASK /c\\BASE_MASK = mask.tif" "filled_${parfile}"
  sed -i "/^NTHREAD_READ /c\\NTHREAD_READ = 1" "filled_${parfile}"
  sed -i "/^NTHREAD_COMPUTE /c\\NTHREAD_COMPUTE = ${params.max_cpu}" "filled_${parfile}"
  sed -i "/^NTHREAD_WRITE /c\\NTHREAD_WRITE = 1" "filled_${parfile}"
  sed -i "/^X_TILE_RANGE /c\\X_TILE_RANGE = ${tile_X} ${tile_X}" "filled_${parfile}"
  sed -i "/^Y_TILE_RANGE /c\\Y_TILE_RANGE = ${tile_Y} ${tile_Y}" "filled_${parfile}"
  sed -i "/^SENSORS /c\\SENSORS = ${params.sensors}" "filled_${parfile}"
  sed -i "/^RESOLUTION /c\\RESOLUTION = ${params.resolution}" "filled_${parfile}"
  sed -i "/^ABOVE_NOISE /c\\ABOVE_NOISE = 0" "filled_${parfile}"
  sed -i "/^BELOW_NOISE /c\\BELOW_NOISE = 0" "filled_${parfile}"
  sed -i "/^DATE_RANGE /c\\DATE_RANGE = ${params.reference_start}-01-01 ${params.monitor_end}-12-31" "filled_${parfile}"
  sed -i "/^DOY_RANGE /c\\DOY_RANGE = ${params.season_start} ${params.season_end}" "filled_${parfile}"
  sed -i "/^INDEX /c\\INDEX = ${params.index}" "filled_${parfile}"
  sed -i "/^INTERPOLATE /c\\INTERPOLATE = HARMONIC" "filled_${parfile}"
  sed -i "/^HARMONIC_FIT_RANGE /c\\HARMONIC_FIT_RANGE = ${params.reference_start}-01-01 ${params.reference_end}-12-31" "filled_${parfile}"
  sed -i "/^HARMONIC_TREND /c\\HARMONIC_TREND = FALSE" "filled_${parfile}"
  sed -i "/^OUTPUT_NRT /c\\OUTPUT_NRT = TRUE" "filled_${parfile}"
  """

}
