#!/bin/bash

#Usage:
#      . ./ResourceManager.sh <mode> <current parallelism> <new parallelism>
# mode=0: only return NDmax of current parallelism
# mode=1: Rescaling the number of TMs by <new parallelism> then return ND_MAX 


##########################
ID_TM0="pico0"
JobManagerLocation="Paris"
#Note: We don't add network delay to Master node (where we run JobManager)

TM1="Brussels"
ID_TM1="pico1"
Delay_TM1="5ms"

TM2="Amsterdam"
ID_TM2="pico2"
Delay_TM2="50ms"

TM3="London"
ID_TM3="pico3"
Delay_TM3="100ms"

TM4="Madrid"
ID_TM4="pico4"
Delay_TM9="55ms"

TM5="Rome"
ID_TM5="pico5"
Delay_TM4="150ms"

TM6="Stockholm"
ID_TM6="pico6"
Delay_TM5="200ms"

TM7="Helsinki"
ID_TM7="pico7"
Delay_TM6="300ms"

TM8="Berlin"
ID_TM8="pico8"
#Delay_TM7="180ms" # We run Job manager in this node without delay

TM9="Vienna"
ID_TM8="pico9"   
#Delay_TM9="45ms" #We run Minio, Prometheous and Grafana in this node without delay


############################
if [ $1 -eq 2 ]
then
    sshpass -p pico ssh guru@pico1-0 kubectl scale --replicas=0 deployment/flink-taskmanager
    sleep 15
    sshpass -p pico ssh guru@pico1-0 kubectl scale --replicas=$2 deployment/flink-taskmanager
    sleep 5
    ###then return Maximum Network Delay
    TMDelay="Delay_TM$2"
    ND_MAX=${!TMDelay}
    #echo "$ND_MAX"

elif [ $1 -eq 1 ]
then
    ###Rescale the number of task managers
    if [ $3 -gt $2 ]
    then
        sshpass -p pico ssh guru@pico1-0 kubectl scale --replicas=$3 deployment/flink-taskmanager
    else
        sshpass -p pico ssh guru@pico1-0 kubectl scale --replicas=0 deployment/flink-taskmanager
        sleep 15
        sshpass -p pico ssh guru@pico1-0 kubectl scale --replicas=$3 deployment/flink-taskmanager
    fi
    sleep 5
    ###then return Maximum Network Delay
    TMDelay="Delay_TM$3"
    ND_MAX=${!TMDelay}
    #echo "$ND_MAX"
else
    ###Only returning Maximum Network Delay
    TMDelay="Delay_TM$2"
    ND_MAX=${!TMDelay}
    #echo "$ND_MAX"
fi
