#!/bin/sh
while : 
do
  ssh blctl@10.109.3.53 tail -n 6 ./stress.log | sed -n -e 's/^.*2016-//p' > a.txt 
  mv a.txt ../a.txt
  sleep 1
done
