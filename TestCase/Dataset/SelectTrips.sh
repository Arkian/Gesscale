#!/bin/bash

#different scripts to select trips


#Change and reorganize the dataset based on the usecase 
#tr -d '\r' | awk -F "," '{print NR ",START," $6 ",1970-01-01 00:00:00," $11 "," $12 "," $13 "," $14 "," $8 "," $1 "," $2}{print NR ",END," $7 "," $6 "," $11 "," $12 "," $13 "," $14 "," $8 "," $1 "," $2}' | sort -t ',' -k 3 -S "4G"


# split ...
#(-d) Split with numeric suffix instead of alphabetic 
#(-l) Split with customize line numbers 
#(-b) Split with file size (-b 50m)
#(-n) Split to n chunks output files




#To select the rides only for 2013-05-01 to 07
#awk /2013-05-01/ RidesMay2013 >Rides2013-05-01
#awk /2013-05-02/ RidesMay2013 >Rides2013-05-02
#awk /2013-05-03/ RidesMay2013 >Rides2013-05-03
#awk /2013-05-04/ RidesMay2013 >Rides2013-05-04
#awk /2013-05-05/ RidesMay2013 >Rides2013-05-05
#awk /2013-05-06/ RidesMay2013 >Rides2013-05-06
#awk /2013-05-07/ RidesMay2013 >Rides2013-05-07



#To select only START records:
#awk /START/ Rides2013-05-01 >Rides2013-05-01_START
#awk /START/ Rides2013-05-02 >Rides2013-05-02_START
#awk /START/ Rides2013-05-03 >Rides2013-05-03_START
#awk /START/ Rides2013-05-04 >Rides2013-05-04_START
#awk /START/ Rides2013-05-05 >Rides2013-05-05_START
#awk /START/ Rides2013-05-06 >Rides2013-05-06_START
#awk /START/ Rides2013-05-07 >Rides2013-05-07_START

#To compress the files to *.gz
# gzip -k Rides2013-05-01
# gzip -k Rides2013-05-02
# gzip -k Rides2013-05-03
# gzip -k Rides2013-05-04
# gzip -k Rides2013-05-05
# gzip -k Rides2013-05-06
# gzip -k Rides2013-05-07

# gzip -k Rides2013-05-01_START
# gzip -k Rides2013-05-02_START
# gzip -k Rides2013-05-03_START
# gzip -k Rides2013-05-04_START
# gzip -k Rides2013-05-05_START
# gzip -k Rides2013-05-06_START
# gzip -k Rides2013-05-07_START

#To concatinate the files to a combined file
#cat Rides2013-05-0* > Rides-Combined
