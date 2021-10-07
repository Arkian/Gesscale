#!/bin/bash


##########################
JobManagerLocation="Paris"
#Note: We don't add network delay to Master node (where we run JobManager)

# The values are just an example, and should be defined based on test scenario.
TM1="Brussels"
ID_TM1="pico1"
Delay_TM1="5ms"

TM2="Amsterdam"
ID_TM2="pico2"
Delay_TM2="10ms"

TM3="London"
ID_TM3="pico3"
Delay_TM3="20ms"

TM4="Madrid"
ID_TM4="pico4"
Delay_TM4="25ms"

TM5="Rome"
ID_TM5="pico5"
Delay_TM5="40ms"

TM6="Stockholm"
ID_TM6="pico6"
Delay_TM6="50ms"

TM7="Helsinki"
ID_TM7="pico7"
Delay_TM7="55ms"

TM8="Berlin"
ID_TM8="pico8"
Delay_TM8="70ms"

TM9="Vienna"
ID_TM9="pico9"
Delay_TM9="90ms"

############################

#Adding Network Latencies
#ssh pico1-0 sudo tc qdisc add dev eth0 root netem delay $Delay_TM0
echo "Adding network latency to pico1..."
ssh pico1-1 sudo tc qdisc add dev eth0 root netem delay $Delay_TM1
echo "Adding network latency to pico2..."
ssh pico1-2 sudo tc qdisc add dev eth0 root netem delay $Delay_TM2
echo "Adding network latency to pico3..."
ssh pico1-3 sudo tc qdisc add dev eth0 root netem delay $Delay_TM3
echo "Adding network latency to pico4..."
ssh pico1-4 sudo tc qdisc add dev eth0 root netem delay $Delay_TM4
echo "Adding network latency to pico5..."
ssh pico1-5 sudo tc qdisc add dev eth0 root netem delay $Delay_TM5
echo "Adding network latency to pico6..."
ssh pico1-6 sudo tc qdisc add dev eth0 root netem delay $Delay_TM6
echo "Adding network latency to pico7..."
ssh pico1-7 sudo tc qdisc add dev eth0 root netem delay $Delay_TM7
echo "Adding network latency to pico8..."
ssh pico1-8 sudo tc qdisc add dev eth0 root netem delay $Delay_TM8
echo "Adding network latency to pico9..."
ssh pico1-9 sudo tc qdisc add dev eth0 root netem delay $Delay_TM9
###########################

# Ping Test
echo "pico0 <<-->> pico0:"
ssh pico1-0 ping -c 1 pico1-0
echo "pico1 <<-->> pico0"
ssh pico1-1 ping -c 1 pico1-0
echo "pico2 <<-->> pico0"
ssh pico1-2  ping -c 1 pico1-0
echo "pico3 <<-->> pico0"
ssh pico1-3 ping -c 1 pico1-0
echo "pico4 <<-->> pico0"
ssh pico1-4 ping -c 1 pico1-0
echo "pico5 <<-->> pico0"
ssh pico1-5 ping -c 1 pico1-0
echo "pico6 <<-->> pico0"
ssh pico1-6 ping -c 1 pico1-0
echo "pico7 <<-->> pico0"
ssh pico1-7 ping -c 1 pico1-0
echo "pico8 <<-->> pico0"
ssh pico1-8 ping -c 1 pico1-0
echo "pico9 <<-->> pico0"
ssh pico1-9 ping -c 1 pico1-0


