#!/bin/bash

# This script is designed to improve the performance and reduce audio latency for sound cards by setting the PCI latency timer to an optimal value of 80 cycles. 
# It also resets the default value of the latency timer for other PCI devices, which can help prevent devices with high default latency timers from causing gaps in sound.

# Reset the latency timer for all PCI devices
sudo setpci -v -s '*:*' latency_timer=20
sudo setpci -v -s '0:0' latency_timer=0

# Find all sound cards
SOUND_CARDS=$(lspci -nd "*:*:04xx" | cut -d " " -f 1)

# Loop through sound cards and set latency timer to 80
for CARD in $SOUND_CARDS; do
    sudo setpci -v -s "$CARD" latency_timer=80
done
