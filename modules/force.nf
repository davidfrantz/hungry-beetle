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
    . \
    tiles.txt
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
    -b "mask" \
    -o "maskdir" \
    "${mask}"
  """

}

// compute pyramids
/* Note: there is a workaround necessary, as gdaladdo (in force-pyramid) 
-- resolves the nextflow symlinks, hence creating the output file at the
-- physical(!) location of the input image. Using the VRT as an middle
-- layer prevents this, and does not generate too much additional data.
-- The overviews need to be renamed afterward as if they were generated
-- based on the tifs, not the vrt. 
-- This workaround keeps the cache alive. */
process force_pyramid {

  label 'force'

  input:
  tuple path(images), val(tile_ID), val(tile_X), val(tile_Y)

  output:
  path "$tile_ID/*.ovr"

  publishDir "${params.publish}/${params.project}", mode: 'copy', overwrite: true, failOnError: true

  """
  mkdir "${tile_ID}"
  for i in *.tif; do
    gdal_translate \
      -of VRT \
      "\$i" \
      "${tile_ID}/\${i%.*}.vrt"
    force-pyramid \
      "${tile_ID}/\${i%.*}.vrt"
    rename \
      's/.vrt/.tif/' \
      "${tile_ID}/\${i%.*}.vrt.ovr"
  done
  """

}




// compute mosaic
/* Note: there is quite some workaround necessary, as Nextflow does not
-- permit staging multiple files with the same name in subfolders of
-- different name, i.e., the usual tile/image structure in a datacube.
-- This workaround solves this issue using the VRT format as a middle
-- layer. Doing so does not generate too much additional data, and has
-- the additional benefit of keeping the cache alive.
-- If there are multipe basenames present, mosaics will be separately
-- generated for all of them. */
workflow force_mosaic {

  take:
  datacube
  // tuple [path files, tile ID, tile ID (X), tile ID (Y)]

  main:
  datacube
  | map{ it[0] } // select the files only
  | flatten // flatten the tuple
  | filter( ~/.*\.tif$/ ) // select tif files only (may contain .aux.xml etc.)
  | map{ [it, it.simpleName, it.parent.name] } // tuple [path, base name without extension, tile name]
  | force_virtual_flat // convert to flat virtual format
  | groupTuple(by: 1) // group by base name
  | force_mosaic_core // compute a mosaic
  //| view

}

// create flat virtual files
/* This process converts a tile/image.tif file to a virtual
-- tile@image.vrt file to help resolve Nextflow staging limitations
-- and help to keep the Nextflow cache alive. */
process force_virtual_flat {

  label 'force'

  input:
  tuple path(image), val(base), val(tile_ID)

  output:
  tuple path("${tile_ID}@${base}.vrt"), val(base)

  """
  outfile=${image.name}
  gdal_translate \
    -of VRT \
    "${image}" \
    "${tile_ID}@${base}.vrt"
  """

}

// recode of force_mosaic
/* Note: this is a re-implementation of the core functionality of `force-mosaic`
-- to enable usage of VRT images.
-- Use this only use with the ``force_mosaic`` workflow, not as standalone process.*/
process force_mosaic_core {

  label 'force'

  input:
  tuple path(images), val(base)

  output:
  path "mosaic/*"

  publishDir "${params.publish}/${params.project}", mode: 'copy', overwrite: true, failOnError: true

  """
  mkdir mosaic
  ls *.vrt > files.txt
  nodata=`head -n 1 files.txt | xargs gdalinfo | grep 'NoData Value' | head -1 | cut -d '=' -f 2`
  gdalbuildvrt \
    -srcnodata \$nodata \
    -vrtnodata \$nodata \
    -input_file_list files.txt \
    mosaic/${base}.vrt
  sed -i -E 's+(X[0-9]{4}_Y[0-9]{4})@+../\\1/+g' mosaic/${base}.vrt
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
  tuple path(parfile), path(datacube), path(maskdir), val(tile_ID), val(tile_X), val(tile_Y)

  output:
  tuple path("${tile_ID}/*"), val(tile_ID), val(tile_X), val(tile_Y), optional: true

  publishDir "${params.publish}/${params.project}", mode: 'copy', overwrite: true, failOnError: true

  """
  force-higher-level "${parfile}"
  """

}

