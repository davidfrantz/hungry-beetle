process force_tile_extent {

  label 'force'

  input:
  path aoi
  path datacube_definition

  output:
  path 'tiles.txt'
  
  """
  force-tile-extent "$aoi" . tiles.txt
  """

}

process force_cube_mask {

  label 'force'
  //label 'multithread'

  input:
  path mask
  path datacube_definition

  output:
  path "maskdir"
  
  """
  mkdir "maskdir"
  cp "$datacube_definition" -t "maskdir"
  force-cube -s "$params.resolution" -b "mask" -o "maskdir" "$mask"
  """

}

process force_pyramid {

  label 'force'

  input:
  tuple path(images), val(tile_ID), val(tile_X), val(tile_Y)

  output:
  path "$tile_ID/*.ovr"

  publishDir "$params.publish/$params.project", mode: 'copy', overwrite: true, failOnError: true

  // gdaladdo (in force-pyramid) resolves the nextflow symlinks, 
  // this here is a workaround without copying data
  """
  mkdir "$tile_ID"
  for i in *.tif; do
    gdal_translate -of VRT "\$i" "$tile_ID/\${i%.*}.vrt"
    force-pyramid "$tile_ID/\${i%.*}.vrt"
    rename 's/.vrt/.tif/' "$tile_ID/\${i%.*}.vrt.ovr"
  done
  """

}

// recode of force_mosaic, only use from ``mosaic`` workflow 
process force_mosaic {

  label 'force'

  input:
  tuple path(images), val(base)

  output:
  path "mosaic/*"

  publishDir "$params.publish/$params.project", mode: 'copy', overwrite: true, failOnError: true

  """
  mkdir mosaic
  ls *.vrt > files.txt
  nodata=`head -n 1 files.txt | xargs gdalinfo | grep 'NoData Value' | head -1 | cut -d '=' -f 2`
  gdalbuildvrt -srcnodata \$nodata -vrtnodata \$nodata -input_file_list files.txt mosaic/${base}.vrt
  sed -i -E 's+(X[0-9]{4}_Y[0-9]{4})@+../\\1/+g' mosaic/${base}.vrt
  sed -i 's/.vrt/.tif/g' mosaic/${base}.vrt
  sed -i 's/relativeToVRT="0"/relativeToVRT="1"/g' mosaic/${base}.vrt
  """

}

process force_parameter {

  label 'force'

  input:
  val module

  output:
  path "${module}.prm"

  """
  force-parameter -c "${module}.prm" "$module"
  """

}

process force_higher_level {

  label 'force'
  label 'multithread'

  input:
  tuple path(parfile), path(datacube), path(maskdir), val(tile_ID), val(tile_X), val(tile_Y)

  output:
  tuple path("$tile_ID/*"), val(tile_ID), val(tile_X), val(tile_Y), optional: true

  publishDir "$params.publish/$params.project", mode: 'copy', overwrite: true, failOnError: true

  """
  force-higher-level "$parfile"
  """

}
