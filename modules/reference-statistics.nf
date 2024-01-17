include { force_parameter }    from './force-core.nf'
include { force_higher_level } from './force-core.nf'
include { force_pyramid }      from './force-core.nf'
include { mosaic }             from './force-glue.nf'

workflow stats_reference_period {

  take:
  datacube_tile

  main:
  stats = force_parameter('TSA') 
  | combine(datacube_tile)
  | fill_parameter_stats
  | force_higher_level

  stats
  | (force_pyramid & mosaic)

  emit:
  stats

}

process fill_parameter_stats {

  input:
  tuple path(parfile), path(datacube), path(maskdir), val(tile_ID), val(tile_X), val(tile_Y)

  output:
  tuple path("filled_${parfile}"), path(maskdir), path(datacube), val(tile_ID), val(tile_X), val(tile_Y)

  """
  cp "$parfile" "filled_${parfile}"
  sed -i "/^DIR_LOWER /c\\DIR_LOWER = $datacube" "filled_${parfile}"
  sed -i "/^DIR_HIGHER /c\\DIR_HIGHER = ." "filled_${parfile}"
  sed -i "/^DIR_PROVENANCE /c\\DIR_PROVENANCE = ." "filled_${parfile}"
  sed -i "/^DIR_MASK /c\\DIR_MASK = maskdir" "filled_${parfile}"
  sed -i "/^BASE_MASK /c\\BASE_MASK = mask.tif" "filled_${parfile}"
  sed -i "/^NTHREAD_READ /c\\NTHREAD_READ = 1" "filled_${parfile}"
  sed -i "/^NTHREAD_COMPUTE /c\\NTHREAD_COMPUTE = $params.max_cpu" "filled_${parfile}"
  sed -i "/^NTHREAD_WRITE /c\\NTHREAD_WRITE = 1" "filled_${parfile}"
  sed -i "/^X_TILE_RANGE /c\\X_TILE_RANGE = $tile_X $tile_X" "filled_${parfile}"
  sed -i "/^Y_TILE_RANGE /c\\Y_TILE_RANGE = $tile_Y $tile_Y" "filled_${parfile}"
  sed -i "/^SENSORS /c\\SENSORS = $params.sensors" "filled_${parfile}"
  sed -i "/^RESOLUTION /c\\RESOLUTION = $params.resolution" "filled_${parfile}"
  sed -i "/^ABOVE_NOISE /c\\ABOVE_NOISE = 0" "filled_${parfile}"
  sed -i "/^BELOW_NOISE /c\\BELOW_NOISE = 0" "filled_${parfile}"
  sed -i "/^DATE_RANGE /c\\DATE_RANGE = ${params.reference_start}-01-01 ${params.reference_end}-12-31" "filled_${parfile}"
  sed -i "/^DOY_RANGE /c\\DOY_RANGE = $params.season_start $params.season_end" "filled_${parfile}"
  sed -i "/^INDEX /c\\INDEX = $params.index" "filled_${parfile}"
  sed -i "/^INTERPOLATE /c\\INTERPOLATE = NONE" "filled_${parfile}"
  sed -i "/^OUTPUT_STM /c\\OUTPUT_STM = TRUE" "filled_${parfile}"
  sed -i "/^STM /c\\STM = STD" "filled_${parfile}"
  """

}
