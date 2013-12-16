#!/bin/bash

TMP=`mktemp -p /tmp`

love level-editor < $1 > $TMP 
if grep -Fq "More magic" $TMP
then
    cat $TMP > $1
else
    echo "Magic not found in output file. Not saved."
fi
