// load input data into channels
workflow load {

  main:
  aoi = Channel.fromPath( params.aoi )
  if (params.mask.is_vector){
    mask = Channel.fromPath( params.mask.directory + '/' + params.mask.file )
  } else {
    mask = Channel.fromPath( params.mask.directory )
  }
  datacube = Channel.fromPath( params.datacube )
  datacube_definition = Channel.fromPath( params.datacube + '/datacube-definition.prj' )

  emit:
  aoi
  mask
  datacube
  datacube_definition

}
