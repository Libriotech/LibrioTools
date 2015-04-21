#!/bin/bash

# Sometimes, records from BIBSYS have records where non-ASCII chars are 
# represented as @ + ASCII-char. For example:
# Stanis@law v.s. Stanisław
# This script tries to catch as many of those cases as possible
# This script should NEVER be run on an ISO2709 file, since it will mess up 
# the field offsets. MARCXML and line format only! 

if [ "$#" -ne 1 ]; then
  echo "Illegal number of parameters"
  exit
fi

FILE=$1

if [ ! -f $FILE ]; then
   echo "File $FILE does not exists."
   exit
else


