#/bin/bash

# directory of program
PROG=`basename $0`;
BIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

path_inp=$1
path_out=$2
resolution=$3

cp $BIN/disturbance_report.Rmd .

Rscript -e \
  "rmarkdown::render('disturbance_report.Rmd', output_file = '$path_out', params = list(path_inp = '$path_inp', resolution = $resolution))"
