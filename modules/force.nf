// retrieve tiles that cover the AOI and emit as channel
workflow force_get_tiles {

  take:
  aoi
  datacube_definition
  // path AOI, path datacube definition
  
  main:
  tiles = force_tile_extent(
    aoi, 
    datacube_definition
  )
  | force_tiles_to_csv // convert tile file to csv table
  | splitCsv(sep: ',', skip: 1) // split the csv into a channel

  emit:
  tiles

}

// tile file is converted to csv
// column 1: original tile ID --- X[0-9]{4}_Y[0-9]{4}
// column 2: X ID             --- [0-9]{4}
// column 3: Y ID             --- [0-9]{4}
process force_tiles_to_csv {

  input:
  path tiles

  output:
  path "${tiles}.csv"

  """
  sed 's/[XY]//g' "${tiles}" | sed 's/_/,/' > temp.csv
  paste -d ',' "${tiles}" temp.csv > "${tiles}.csv"
  """

}

// compute tiles that cover the AOI
process force_tile_extent {

  label 'force'

  input:
  path aoi
  path datacube_definition

  output:
  path 'tiles.txt'
  
  """
  force-tile-extent \
    "${aoi}" \
    -a tiles.txt
  """

}

// compute processing masks
process force_analysis_masks {

  label 'force'
  //label 'multithread'

  input:
  path mask
  path datacube_definition

  output:
  path "maskdir"
  
  """
  mkdir "maskdir"
  cp "${datacube_definition}" -t "maskdir"
  force-cube \
    -s "${params.resolution}" \
    -o "maskdir" \
    "${mask}"
  """

}

// compute pyramids and mosaic
workflow force_finish {

  take:
  datacube
  // tuple [path files, tile ID, tile ID (X), tile ID (Y), product]

  main:
  all_images = datacube
  | transpose
  | filter({ it[0].extension.matches("tif") }) // select tif files only (may contain .aux.xml etc.)
  //| map{ [it[1], it[2], it[3], it[4], it[0], it[0].simpleName ] } // tile ID, X, Y, product, filename, basename
//
  //all_images
  | groupTuple(by: [1,2,3,4]) // group by tile ID, X, Y, product
  | force_pyramid // convert to flat virtual format, compute pyramids
  | transpose
  | map{ [ it[1], it[2], it[3], it[4], it[5], it[0].simpleName ] } // vrt, tile ID, X, Y, product, basename
  | groupTuple(by: [4,5]) // group by base name and product
  | force_mosaic // compute mosaic
  //| view

}

// create flat virtual files
/* This process converts a tile/image.tif file to a virtual
-- tile@product@image.vrt file to help resolve Nextflow staging limitations
-- and help to keep the Nextflow cache alive. 
-- Plus, it computes pyramids obviously.
-- Note: there is a workaround necessary here, as gdaladdo (in force-pyramid) 
-- resolves the nextflow symlinks, hence creating the output file at the
-- physical(!) location of the input image. Using the VRT as an middle
-- layer prevents this, and does not generate too much additional data.
-- This workaround keeps the cache alive. */
process force_pyramid {

  label 'force'
  label 'multithread'

  input:
  tuple path("input/*"), val(tile_ID), val(tile_X), val(tile_Y), val(product)

  output:
  tuple path("*.ovr"), path("*.vrt"), val(tile_ID), val(tile_X), val(tile_Y), val(product)

  publishDir "${params.publish}/${params.project}", 
    pattern: '*.ovr',
    saveAs: {fn -> "${tile_ID}/${product}/${file(fn).name}"}, 
    mode: 'copy', overwrite: true, failOnError: true

  """
  ls input/*.tif | \
    parallel -j $params.max_cpu \
      "gdal_translate -of VRT {} {/.}.vrt; \
       force-pyramid {/.}.vrt; \
       rename 's/.vrt/.tif/' {/.}.vrt.ovr; \
       mv {/.}.vrt ${tile_ID}@${product}@{/.}.vrt"
  """

}

// recode of force_mosaic
/* Note: this is a re-implementation of the core functionality of `force-mosaic`
-- to enable usage of VRT images.
-- Use this only use with the ``force_finish`` workflow, not as standalone process.
-- There is quite some workaround necessary, as Nextflow does not
-- permit staging multiple files with the same name in subfolders of
-- different name, i.e., the usual tile/image structure in a datacube.
-- This workaround solves this issue using the VRT format as a middle
-- layer. Doing so does not generate too much additional data, and has
-- the additional benefit of keeping the cache alive.
-- If there are multipe basenames present, mosaics will be separately
-- generated for all of them. */
process force_mosaic {

  label 'force'
  
  input:
  tuple path(vrt), val(tile_ID), val(tile_X), val(tile_Y), val(product), val(base)

  output:
  path "mosaic/*"

  publishDir "${params.publish}/${params.project}", 
    saveAs: {fn -> "mosaic/${product}/${file(fn).name}"}, 
    mode: 'copy', overwrite: true, failOnError: true

  """
  mkdir -p mosaic
  ls *.vrt > files.txt
  nodata=`head -n 1 files.txt | xargs gdalinfo | grep 'NoData Value' | head -1 | cut -d '=' -f 2`
  gdalbuildvrt \
    -srcnodata \$nodata \
    -vrtnodata \$nodata \
    -input_file_list files.txt \
    mosaic/${base}.vrt
  sed -i -E 's+(X[0-9]{4}_Y[0-9]{4})+../../\\1+g' mosaic/${base}.vrt
  sed -i 's+@+/+g' mosaic/${base}.vrt
  sed -i 's/.vrt/.tif/g' mosaic/${base}.vrt
  sed -i 's/relativeToVRT="0"/relativeToVRT="1"/g' mosaic/${base}.vrt
  """

}

// generate a parameter file with given module type
process force_parameter {

  label 'force'

  input:
  val module

  output:
  path "${module}.prm"

  """
  force-parameter \
    -c \
    "${module}.prm" \
    "${module}"
  """

}

// higher-level processing
process force_higher_level {

  label 'force'
  label 'multithread'

  input:
  tuple path(parfile), path(datacube), path(maskdir), val(tile_ID), val(tile_X), val(tile_Y), val(product)

  output:
  tuple path("${tile_ID}/*"), val(tile_ID), val(tile_X), val(tile_Y), val(product), optional: true

  publishDir "${params.publish}/${params.project}", 
    saveAs: {fn -> "${tile_ID}/${product}/${file(fn).name}"}, 
    mode: 'copy', overwrite: true, failOnError: true

  """
  force-higher-level "${parfile}"
  """

}

