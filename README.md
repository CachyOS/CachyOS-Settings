# CachyOS-Settings
This repository contains configuration files that tweak sysctl values, add udev rules to automatically set schedulers, and provide additional optimizations.

## udev rules
- ZRAM
- Audio latency
- SATA, power management for HDD to prioritize max performance 
- IO schedulers, automatic selection schedulers depends on your HW - SATA SSD, NVME and HDD.
- NVIDIA, load, unload modules and set-up power management. 

## sysctl
Tweaks focused to memory and network.

## modprobe
- NVIDIA and enable direct rendering
- Force using of the amdgpu driver for Southern Islands (GCN 1.0+) and Sea

## systemd
- PCI latency
