#!/bin/bash

x=1
for line in `awk -F "-" '{print $NF}' out`
do
  ((x=$x+1))
  echo -n "\"$line\","
  if [ $x -ge 5 ]
  then
    echo
    x=1
  fi
done
echo
