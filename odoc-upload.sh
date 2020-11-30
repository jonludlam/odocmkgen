#!/bin/bash

set -e -x

cd prep/universes
for i in $(find . -type d -depth 1 | cut -c3); do
  for j in $(find $i -type d -depth 2); do
    fname=$(echo $j | sed sx/x_xg)
    echo $fname
    if [ ! $(s3cmd ls s3://docs.ocaml.org-cmts/ | grep $fname) ]; then
      tar jcf $fname.tar.bz2 $j
      s3cmd put $fname.tar.bz2 s3://docs.ocaml.org-cmts/
    else
      echo $fname already exists!
    fi
  done
done

