include { force_tile_extent } from './force-core.nf'
include { force_cube_mask }   from './force-core.nf'
include { force_mosaic }      from './force-core.nf'

workflow get_tiles {

  take:
  aoi
  datacube_definition
  
  main:
  tiles = force_tile_extent(
    aoi, 
    datacube_definition
  )
  | tiles_to_csv
  | splitCsv(sep: ',', skip: 1)

  emit:
  tiles

}

workflow mosaic {

  take:
  datacube

  main:
  datacube
  | map{ it[0] }
  | flatten
  | filter( ~/.*\.tif$/ )
  | map{ [it, it.simpleName, it.parent.name] }
  | virtual_flat
  | groupTuple(by: 1)
  | force_mosaic
  //| view

}


process virtual_flat {

  label 'force'

  input:
  tuple path(image), val(base), val(tile_ID)

  output:
  tuple path("${tile_ID}@${base}.vrt"), val(base)

  """
  outfile=${image.name}
  gdal_translate -of VRT "${image}" "${tile_ID}@${base}.vrt"
  """

}

workflow analysis_masks {

  take:
  mask
  datacube_definition

  main:
  masks = force_cube_mask(
    mask, 
    datacube_definition
  )

  emit:
  masks

}

// tile file is converted to csv
// column 1: original tile ID --- X[0-9]{4}_Y[0-9]{4}
// column 2: X ID             --- [0-9]{4}
// column 3: Y ID             --- [0-9]{4}
process tiles_to_csv {

  input:
  path tiles

  output:
  path "${tiles}.csv"

  """
  sed 's/[XY]//g' "$tiles" | sed 's/_/,/' > temp.csv
  paste -d ',' "$tiles" temp.csv > "${tiles}.csv"
  """

}

