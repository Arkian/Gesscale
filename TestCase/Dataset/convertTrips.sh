#!/bin/bash

# usage: just pipe raw data into script

tr -d '\r' | awk -F "," '{print NR ",START," $6 ",1970-01-01 00:00:00," $11 "," $12 "," $13 "," $14 "," $8 "," $1 "," $2}{print NR ",END," $7 "," $6 "," $11 "," $12 "," $13 "," $14 "," $8 "," $1 "," $2}' | sort -t ',' -k 3 -S "4G" < /dev/stdin
