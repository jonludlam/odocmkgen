#!/bin/bash

set -e -x

export PATH=$PATH:$HOME/.local/bin/

cd prep/universes

s3cmd ls s3://docs.ocaml.org-cmts/ > uploaded

for i in $(find . -type d -maxdepth 1 -mindepth 1 | cut -c3- ); do
  for j in $(find $i -type d -maxdepth 2 -mindepth 2); do
    fname=$(echo $j | sed sx/x_xg)
    universe=$(echo $j | cut -d/ -f1)
    echo $fname
    if grep $fname uploaded; then
      echo $fname already exists!
    else
      tar jcf $fname.tar.bz2 $universe/packages.usexp $j
      s3cmd put $fname.tar.bz2 s3://docs.ocaml.org-cmts/
    fi
  done
done

