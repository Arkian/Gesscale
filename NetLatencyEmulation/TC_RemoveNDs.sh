#!/bin/bash

############################

#Removing Network Latencies
#ssh pico1-0 sudo tc qdisc del dev eth0 root
echo "Removing network latency to pico1..."
ssh pico1-1 sudo tc qdisc del dev eth0 root
echo "Removing network latency to pico2..."
ssh pico1-2 sudo tc qdisc del dev eth0 root
echo "Removing network latency to pico3..."
ssh pico1-3 sudo tc qdisc del dev eth0 root
echo "Removing network latency to pico4..."
ssh pico1-4 sudo tc qdisc del dev eth0 root
echo "Removing network latency to pico5..."
ssh pico1-5 sudo tc qdisc del dev eth0 root
echo "Removing network latency to pico6..."
ssh pico1-6 sudo tc qdisc del dev eth0 root
echo "Removing network latency to pico7..."
ssh pico1-7 sudo tc qdisc del dev eth0 root
echo "Removing network latency to pico8..."
ssh pico1-8 sudo tc qdisc del dev eth0 root
echo "Removing network latency to pico9..."
ssh pico1-9 sudo tc qdisc del dev eth0 root
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


