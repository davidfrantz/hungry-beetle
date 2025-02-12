#include <stdio.h>
#include <stdlib.h>

/** Geospatial Data Abstraction Library (GDAL) **/
#include "gdal.h"       // public (C callable) GDAL entry points
#include "cpl_conv.h"   // various convenience functions for CPL
#include "cpl_string.h" // various convenience functions for strings


#include "utils/const.h"
#include "utils/alloc.h"
#include "utils/date.h"
#include "utils/dir.h"
#include "utils/string.h"


typedef struct {
  int n;
  char path_stats[STRLEN];
  char path_residuals[STRLEN];
  char file_output[STRLEN];
  float threshold_std;
  float threshold_min;
  int direction;
} args_t;

void usage(char *exe, int exit_code){


  printf("Usage: %s -j cpus -s path_stats -r path_residuals\n", exe);
  printf("          -o file_output -d threshold_std -m threshold_min -e direction\n");
  printf("\n");
  printf("  -s = path to statistics\n");
  printf("  -r = path to residuals\n");
  printf("  -o = output file (.tif)\n");
  printf("  -d = standard deviation threshold\n");
  printf("  -m = minimum residuum threshold\n");
  printf("  -e = direction of testing the threshold\n");
  printf("       +1 for 'greater than' test\n");
  printf("       -1 for 'less than' test\n");
  printf("\n");

  exit(exit_code);
  return;
}

void parse_args(int argc, char *argv[], args_t *args){
int opt, received_n = 0, expected_n = 6;

  opterr = 0;

  while ((opt = getopt(argc, argv, "s:r:o:d:m:e:")) != -1){
    switch(opt){
      case 's':
        copy_string(args->path_stats, STRLEN, optarg);
        received_n++;
        break;
      case 'r':
        copy_string(args->path_residuals, STRLEN, optarg);
        received_n++;
        break;
      case 'o':
        copy_string(args->file_output, STRLEN, optarg);
        received_n++;
        break;
      case 'd':
        args->threshold_std = atof(optarg);
        if (args->threshold_std < 1){
          fprintf(stderr, "threshold_std must be >= 1\n");
          usage(argv[0], FAILURE);  
        }
        received_n++;
        break;
      case 'm':
        args->threshold_min = atof(optarg);
        if (args->threshold_min < 1){
          fprintf(stderr, "threshold_min must be >= 1\n");
          usage(argv[0], FAILURE);  
        }
        received_n++;
        break;
      case 'e':
        args->direction = atoi(optarg);
        received_n++;
        break;
      case '?':
        if (isprint(optopt)){
          fprintf(stderr, "Unknown option `-%c'.\n", optopt);
        } else {
          fprintf(stderr, "Unknown option character `\\x%x'.\n", optopt);
        }
        usage(argv[0], FAILURE);
      default:
        fprintf(stderr, "Error parsing arguments.\n");
        usage(argv[0], FAILURE);
    }
  }

  if (received_n != expected_n){
    fprintf(stderr, "Not all arguments received.\n");
    usage(argv[0], FAILURE);
  }

  return;
}


int list_files(char *input_dir, char *product, dir_t *dir){
int i;
dir_t d;
char ext[STRLEN];


  copy_string(d.name, STRLEN, input_dir);
  printf("scanning %s for files\n", d.name);

  // directory listing
  if ((d.N = scandir(d.name, &d.LIST, 0, alphasort)) < 0){
    return FAILURE;}

  printf("found %d files, filtering now\n", d.N);

  // reflectance products
  alloc_2D((void***)&d.files, d.N, STRLEN, sizeof(char));
  alloc_2D((void***)&d.paths, d.N, STRLEN, sizeof(char));

  for (i=0, d.n=0; i<d.N; i++){

    // filter expected extensions    
    extension(d.LIST[i]->d_name, ext, STRLEN);
    if (strcmp(ext, ".tif")) continue;

    // filter product type
    if (strstr(d.LIST[i]->d_name, product) == NULL) continue;

    // if we are still here, copy
    copy_string(d.files[d.n], STRLEN, d.LIST[i]->d_name);
    concat_string_2(d.paths[d.n], STRLEN, d.name, d.files[d.n], "/");
    d.n++;

  }

  if (d.n<1){
    free_2D((void**)d.files, d.N);
    free_2D((void**)d.paths, d.N);
    free_2D((void**)d.LIST, d.N);
    d.files = NULL;
    d.paths = NULL;
    d.LIST = NULL;
    return FAILURE;
  }

  printf("%d datasets in here. Proceed.\n", d.n);

  *dir = d;
  return SUCCESS;
}


int get_date(date_t *date, char *bname){
char cy[5], cm[3], cd[3];
date_t d;
int i, number = 0, substring = 0;


  for (i=strlen(bname)-1; i>=0; i--){

  
    if (isdigit(bname[i])){

      if (number == 0) substring = i;
      number++;

    } else {

      number = 0;

    }

    //printf("%d, %c, %d, %d\n", i, bname[i], number, substring);

    if (number == 8){

      strncpy(cy, bname+substring,   4); cy[4] = '\0';
      strncpy(cm, bname+substring+4, 2); cm[2] = '\0';
      strncpy(cd, bname+substring+6, 2); cd[2] = '\0';

      init_date(&d);
      set_date(&d, atoi(cy), atoi(cm), atoi(cd));
      
      break;

    }

  }

  
 
  //printf("date is: %04d (Y), %02d (M), %02d (D), %03d (DOY), %02d (W), %d (CE)\n",
  //  d.year, d.month, d.day, d.doy, d.week, d.ce);

  if (d.year < 1900   || d.year > 2100)   return FAILURE;
  if (d.month < 1     || d.month > 12)    return FAILURE;
  if (d.day < 1       || d.day > 31)      return FAILURE;
  if (d.doy < 1       || d.doy > 365)     return FAILURE;
  if (d.week < 1      || d.week > 52)     return FAILURE;
  if (d.ce < 1900*365 || d.ce > 2100*365) return FAILURE;

  *date = d;
  
  return SUCCESS;
}



int main ( int argc, char *argv[] ){
args_t args;
dir_t files_residuals;
dir_t files_stats;
date_t *dates;
int i, j, nx, ny, nc;
int d, nd;

  parse_args(argc, argv, &args);

  GDALAllRegister();


  if (list_files(args.path_residuals, "NRT", &files_residuals) == FAILURE){
    fprintf(stderr, "Could not list files in %s.\n", args.path_residuals);
  }

  if (list_files(args.path_stats, "STM", &files_stats) == FAILURE){
    fprintf(stderr, "Could not list files in %s.\n", args.path_stats);
  }

  nd = files_residuals.n;
  alloc((void**)&dates, nd, sizeof(date_t));
  for (d=0; d<nd; d++) get_date(&dates[d], files_residuals.files[d]);





GDALDatasetH  fp_stats;
GDALDatasetH *fp_residuals;
GDALRasterBandH band_stats;
GDALRasterBandH *band_residuals;



short nodata_stats;
short *nodata_residuals;
int has_nodata;

short *detection = NULL;
short *stats = NULL;
short **residuals = NULL;

char proj[STRLEN];
double geotran[6];


  if ((fp_stats = GDALOpen(files_stats.paths[0], GA_ReadOnly))== NULL){ 
    fprintf(stderr, "could not open %s\n", files_stats.files[0]); exit(FAILURE);}
  band_stats = GDALGetRasterBand(fp_stats, 1);

  nx  = GDALGetRasterXSize(fp_stats);
  ny  = GDALGetRasterYSize(fp_stats);
  nc = nx*ny;

  copy_string(proj, STRLEN, GDALGetProjectionRef(fp_stats));
  GDALGetGeoTransform(fp_stats, geotran);

  nodata_stats = (short)GDALGetRasterNoDataValue(band_stats, &has_nodata);
  if (!has_nodata){
    fprintf(stderr, "%s has no nodata value.\n", files_stats.files[0]); 
    exit(1);
  }


  printf("dimensions: %d x %d x %d\n", ny, nx, nd);

  alloc((void**)&fp_residuals, nd, sizeof(GDALDatasetH));
  alloc((void**)&band_residuals, nd, sizeof(GDALRasterBandH));
  alloc((void**)&nodata_residuals, nd, sizeof(short));

  for (d=0; d<nd; d++){
    printf("open: %s\n", files_residuals.paths[d]);
    if ((fp_residuals[d] = GDALOpen(files_residuals.paths[d], GA_ReadOnly))== NULL){ 
      fprintf(stderr, "could not open %s\n", files_residuals.files[d]); exit(FAILURE);}
    if (nx != GDALGetRasterXSize(fp_residuals[d])){
      fprintf(stderr, "dimension mismatch between %s and %s\n", files_stats.files[0], files_residuals.files[d]); exit(FAILURE);}
    if (ny != GDALGetRasterYSize(fp_residuals[d])){
      fprintf(stderr, "dimension mismatch between %s and %s\n", files_stats.files[0], files_residuals.files[d]); exit(FAILURE);}
    band_residuals[d] = GDALGetRasterBand(fp_residuals[d], 1);
    nodata_residuals[d] = (short)GDALGetRasterNoDataValue(band_residuals[d], &has_nodata);
    if (!has_nodata){
      fprintf(stderr, "%s has no nodata value.\n", files_residuals.files[d]); 
      exit(FAILURE);
  }

  }

  alloc((void**)&detection, nc, sizeof(short));
  alloc((void**)&stats, nx, sizeof(short));
  alloc_2D((void***)&residuals, nd, nx, sizeof(short));

bool valid_line;
bool confirmed;
int number, candidate;

  for (i=0; i<ny; i++){

    if (GDALRasterIO(band_stats, GF_Read, 0, i, nx, 1, 
      stats, nx, 1, GDT_Int16, 0, 0) == CE_Failure){
      printf("could not read line %d.\n", i); exit(FAILURE);}

    for (j=0, valid_line=false; j<nx; j++){
      if (stats[j] != nodata_stats){
        valid_line = true;
        break;
      } 
    }

    if (!valid_line) continue;
    

    for (d=0; d<nd; d++){
      if (GDALRasterIO(band_residuals[d], GF_Read, 0, i, nx, 1, 
        residuals[d], nx, 1, GDT_Int16, 0, 0) == CE_Failure){
        printf("could not read line %d.\n", i); exit(FAILURE);}
    }

    for (j=0; j<nx; j++){

      if (stats[j] == nodata_stats) continue;

      number = candidate = 0;
      confirmed = false;

      for (d=0; d<nd; d++){

        if (residuals[d][j] == nodata_residuals[d]) continue;

        // reset counting when starting new year
        if (d > 0 && dates[d].year != dates[d-1].year) number = 0;

        if (
          (args.direction > 0 && 
           residuals[d][j] > (args.threshold_std * stats[j]) &&
           residuals[d][j] > args.threshold_min) ||
          (args.direction < 0 && 
           residuals[d][j] < (-1 * args.threshold_std * stats[j]) &&
           residuals[d][j] < args.threshold_min)
        ){
          number++;
          if (number == 1) candidate = d;
          if (number == 3){
             confirmed = true;
             break;
          }
        } else {
          number = 0;
        }

      }

      if (!confirmed) continue;

      detection[i*nx+j] = dates[candidate].ce - 1970*365;

    }
    

  }


  GDALClose(fp_stats);
  for (d=0; d<nd; d++) GDALClose(fp_residuals[d]);


GDALDatasetH fp_output = NULL;
GDALRasterBandH band_output = NULL;
GDALDriverH driver = NULL;
char **options = NULL;

  if ((driver = GDALGetDriverByName("GTiff")) == NULL){
    printf("%s driver not found\n", "GTiff"); exit(FAILURE);}

  options = CSLSetNameValue(options, "COMPRESS", "LZW");
  options = CSLSetNameValue(options, "PREDICTOR", "2");
  options = CSLSetNameValue(options, "BIGTIFF", "YES");
  options = CSLSetNameValue(options, "TILED", "YES");


  if ((fp_output = GDALCreate(driver, args.file_output, nx, ny, 1, GDT_Int16, options)) == NULL){
    printf("Error creating file %s.\n", args.file_output); exit(FAILURE);}

  band_output = GDALGetRasterBand(fp_output, 1);

  
  if (GDALRasterIO(band_output, GF_Write, 0, 0, 
    nx, ny, detection, 
    nx, ny, GDT_Int16, 0, 0) == CE_Failure){
    printf("Unable to write %s.\n", args.file_output); exit(FAILURE);}

  GDALSetDescription(band_output, "disturbance detection");
  GDALSetRasterNoDataValue(band_output, 0);

printf("WKT: %s\n", proj);
  GDALSetGeoTransform(fp_output, geotran);
  GDALSetProjection(fp_output,   proj);

  GDALClose(fp_output);



  free((void*)dates);
  free((void*)detection);
  free((void*)stats);
  free((void*)fp_residuals);
  free((void*)band_residuals);
  free((void*)nodata_residuals);
  free_2D((void**)residuals, nd);
  if (options != NULL) CSLDestroy(options);   

  return SUCCESS; 
}

