// load input data into channels
workflow load {

  main:
  aoi = Channel.fromPath( params.aoi )
  mask = Channel.fromPath( params.mask )
  datacube = Channel.fromPath( params.datacube )
  datacube_definition = Channel.fromPath( params.datacube + '/datacube-definition.prj' )

  emit:
  aoi
  mask
  datacube
  datacube_definition

}
