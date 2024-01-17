#/bin/bash

# directory of program
PROG=`basename $0`;
BIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# output directory
publishdir=`grep '^ *publish *= *' beetle.config | sed 's/.* *= *//' | tr -d \'\"`
project=`grep '^ *project *= *' beetle.config | sed 's/.* *= *//' | tr -d \'\"`
launchdir="$publishdir/$project"

# create output directory
mkdir -p $launchdir

# go to output directoy (needed to store Nextflow cache in here)
cd $launchdir

nextflow run -resume -c "$BIN/beetle.config" "$BIN/beetle.nf"
