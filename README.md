# CachyOS-Settings
This repository provides a collection of configuration files and scripts to optimize CachyOS installations. These settings are designed to enhance system performance, responsiveness, and resource management for technical users.

## Core System Optimizations

### ⚙️ Udev Rules: Device Event Automation
Udev rules automatically apply system configurations upon device detection or state changes.
* **Audio Power Management**: Manages `snd-hda-intel` power saving to mitigate audio crackling, disabling it when AC-powered and re-enabling on battery.
* **ZRAM Swap Optimization**: When ZRAM initializes, raises `vm.swappiness` to `150` and disables Zswap so anonymous pages are compressed instead of flushed from the page cache.
* **Device Permissions**: Sets `rtc0` and `hpet` device group to "audio" for proper application access.
* **SATA Performance**: Configures SATA host link power management to `max_performance`.
* **I/O Scheduler Assignment**: Dynamically assigns I/O schedulers: `bfq` for HDDs, `mq-deadline` for SATA SSDs and eMMC, and `kyber` for NVMe SSDs.
* **HDD Performance Tuning**: Applies `hdparm` settings (`-B 254 -S 0`) to rotational ATA disks.
* **NVIDIA Runtime Power Management**: Enables/disables NVIDIA GPU runtime power management on driver bind/unbind events.
* **CPU DMA Latency Access**: Sets permissions for the `cpu_dma_latency` device.
* **Wireless Regulatory Domain**: Triggers setting of the wireless regulatory domain when a Wi-Fi device is added.

### 🚀 Sysctl: Kernel Runtime Configuration
Sysctl parameters modify kernel behavior at runtime for system-wide performance and stability.
* **Memory & I/O Management**: Sets `vm.swappiness=100` at boot, along with `vm.vfs_cache_pressure`, `vm.dirty_bytes`, `vm.dirty_background_bytes`, and `vm.dirty_writeback_centisecs` for balanced memory usage and efficient disk I/O. Disables `vm.page-cluster`.
* **System Stability & Security**: Disables `kernel.nmi_watchdog`, enables `kernel.unprivileged_userns_clone`, and restricts `kernel.kptr_restrict`.
* **Logging & Network**: Configures `kernel.printk` to hide messages from console, increases `net.core.netdev_max_backlog`, and sets `fs.file-max`.

### 🔧 Modprobe: Kernel Module Parameters
Modprobe configurations control module loading and behavior for hardware-specific optimizations.
* **AMD GPU Driver Enforcement**: Enables `amdgpu` SI/CIK support and disables the corresponding `radeon` support for GCN 1.0+ and 2.x GPUs.
* **Watchdog Module Blacklist**: Prevents loading of Intel TCO and AMD SP5100 watchdog timers.
* **NVIDIA Driver Optimizations**: Applies `NVreg_InitializeSystemMemoryAllocations=0` (disables memory clearing for GPU allocations), `NVreg_DynamicPowerManagement=0x02` (mobile GPU power saving), and `NVreg_EnableS0ixPowerManagement=1` (S0ix idle power saving on supported laptops).

### ⏱️ Systemd: Service & System Management
Systemd unit and configuration files for streamlined boot, resource management, and service control.
* **Journal Log Limits**: Sets `journald` size limit to 50MB.
* **Service Timeouts**: Defines `DefaultTimeoutStartSec` (15s) and `DefaultTimeoutStopSec` (10s) for system and user services.
* **File Descriptor Limits**: Increases `DefaultLimitNOFILE` for both system (2048:2097152) and user (1024:1048576) services.
* **Time Synchronization**: Configures `systemd-timesyncd` with Cloudflare and Google NTP servers.
* **ZRAM Generator**: Configures ZRAM with `zstd` compression, `ram` size, and `swap-priority=100`.
* **PCI Latency Service**: Provides a oneshot unit to run the `pci-latency` script at boot (enable manually with `systemctl enable --now pci-latency.service`).
* **Wireless Regulatory Domain**: Sets the regulatory domain from timezone or `/etc/iw-regdomain`, and re-applies it when `/etc/localtime` changes.
* **User Service Resource Delegation**: Delegates CPU, cpuset, IO, memory, and pids to user services.
* **RealtimeKit Logging**: Limits `rtkit-daemon` log verbosity to `info`.

### 🧹 Tmpfiles: Temporary File & THP Management
Configurations for temporary file cleanup and Transparent Huge Page (THP) behavior.
* **Coredump Retention**: Clears coredumps older than 3 days.
* **THP Defragmentation**: Sets `transparent_hugepage/defrag` to `defer+madvise` for tcmalloc-using applications.
* **THP Shrinker**: Configures `khugepaged/max_ptes_none` for Kernel 6.12+ to optimize THP memory usage.

### 🌐 Network & Modules
* **NetworkManager DNS**: Uses `systemd-resolved` for DNS resolution.
* **NTSync Module**: Loads the `ntsync` kernel module at boot.

### 🔊 Audio & Debugging
* **Realtime Audio Priority**: Grants the `@audio` group `rtprio 99` via `/etc/security/limits.d`.
* **Debuginfod**: Points debug symbol lookup to `https://debuginfod.cachyos.org`.

### 🖥️ Display & Login
* **Touchpad Tapping**: Enables tapping for libinput touchpads under X11.
* **GDM Login Logo**: Sets the CachyOS SVG as the GNOME login screen logo.

### ⚡️ Utility Scripts
Bash and Lua scripts for system diagnostics, optimization, and administration.
* **`cachyos-bugreport.sh`**: Generates a comprehensive system bug report including hardware, logs, and installed packages, with an option to upload. (Requires root)
* **`dlss-swapper`**: Forces latest NVIDIA DLSS presets (SR, RR, FG) and updates DLLs via NGX.
* **`dlss-swapper-dll`**: Forces latest NVIDIA DLSS presets (SR, RR, FG) but skips NGX updater.
* **`game-performance`**: Sets CPU power profile to "performance" via `powerprofilesctl` when launching applications, with screensaver inhibition by default. Set `GAME_PERFORMANCE_SCREENSAVER_ON=1` to skip inhibition.
* **`kerver`**: Displays kernel version, x86_64 support, CPU config, and disk scheduler information.
* **`paste-cachyos`**: Uploads file content or stdin to `https://paste.cachyos.org`.
* **`pci-latency`**: Adjusts PCI latency timers for audio and other devices (sets sound cards to 80 cycles). (Requires root)
* **`sbctl-batch-sign`**: Helps batch sign files for Secure Boot, excluding common Microsoft/Windows EFI, .mui, .dll, and grub files. (Requires root, incompatible with Limine)
* **`topmem`**: A Lua script to display top processes by memory consumption (RSS, Swap, KSM profit), with sorting options. (Requires `lua-luv`)
* **`zink-run`**: Wrapper to run OpenGL applications using the Zink Gallium driver.
