#!/usr/bin/bash

# Uncomment or Comment what you might want to use or not.

############################################################################

# Enable NTSync (if available)
# Can result in smoother experience and in some cases increased performance
# export PROTON_USE_NTSYNC=1

# Enable FSync (recommend to disable if using any other)
export PROTON_NO_FSYNC=0
export WINEFSYNC_FUTEX2=0
export WINEFSYNC=0

# Disable ESync
export PROTON_NO_ESYNC=1
export WINEESYNC=0

# Disable Wine Sync and Fast Sync
export WINE_DISABLE_FAST_SYNC=1
export WINEESYNC=0
export PROTON_USE_WINESYNC=0
export PROTON_USE_WINED3D=0

# Enable Native Wayland Driver (if available)
# export PROTON_ENABLE_WAYLAND=1

# Fix stuttering due to Steam overlay
export LD_PRELOAD=""

# Reduce input lag, in exchange of a bit lower fps
# https://github.com/HansKristian-Work/vkd3d-proton/issues/2273
export VKD3D_SWAPCHAIN_LATENCY_FRAMES=2

# May work like DXVK numBackBuffers, which low value could reduce latency in some way.
# export VKD3D_SWAPCHAIN_IMAGES=1

# Unsafe speed hack on NVIDIA. May or may not give a significant performance uplift.
# no_upload_hvv - May free up vital VRAM in certain critical situations, at cost of lower GPU performance.
# nodxr - May help disable raytracing if the implementaion are not working well with linux and forcing.
# You can use additional config by separating in the same line with a comma.
export VKD3D_CONFIG=force_static_cbv

# Set realtime priority for the wineserver which can result in improved performance
export STAGING_RT_PRIORITY_SERVER=90
export STAGING_RT_PRIORITY_BASE=90

# Enable Enable Hardware Accelerated GPU Scheduling
# Can result in improved performance
export WINEHAGS=1
export WINE_DISABLE_HARDWARE_SCHEDULING=0

# Prefer SDL instead of Hidraw
# May help increase compatibility with different devices
export PROTON_PREFER_SDL=1
export SDL_JOYSTICK_HIDAPI=0

# May help fix alt+tab issue
export SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS=0

# Enable MangoHUD (if installed)
export MANGOHUD=1

# Enable VKBasalt (if installed)
export ENABLE_VKBASALT=1

# Disable hide nvidia gpu
# By enabling it could help with compatibility issues in games that have better AMD support.
export PROTON_HIDE_NVIDIA_GPU=0

# Enable HDR
# export DXVK_HDR=1
# export ENABLE_HDR_WSI=1

# Can increase performance
# It may break in some games, but rarely does.
export STAGING_SHARED_MEMORY=1
export STAGING_WRITECOPY=1

# Load shared objects immediately for better first time latency
# https://wiki.archlinux.org/title/Gaming#Load_shared_objects_immediately_for_better_first_time_latency
export LD_BIND_NOW=1

# Use latest shader level and model
export VKD3D_FEATURE_LEVEL=12_2
export VKD3D_SHADER_MODEL=6_6

# Enable hack to disable Vulkan other process window rendering which sometimes causes issues on Wayland due to blit being one frame behind.
export WINE_DISABLE_VULKAN_OPWR=1

# Disable latency markers
export DXVK_NVAPI_USE_LATENCY_MARKERS=0

# Enable LatencyFlex (if you have it installed and setup)
export LFX=1

# Show shader compiling percentage when happening to know why fps are lower in some cases.
export DXVK_HUD=compiler

# https://gitlab.com/Ph42oN/dxvk-gplasync
# May help if you are using dxvk async version
# This version can help in some edge cases, but most of the time, it's recommended to stay in the default.
# export DXVK_ASYNC=1
# export DXVK_GPLASYNCCACHE=1

# May help 32-bit games with address space limitations
export WINE_LARGE_ADDRESS_AWARE=1

# Disable valve fullscreen hack and rely on monitor scaling instead
export WINE_DISABLE_FULLSCREEN_HACK=1

# Enable NVAPI
# It may be enabled by default, but will leave here anyhow
export PROTON_ENABLE_NVAPI=1

# If you are running a game with EAC (anticheat)
export PROTON_USE_EAC_LINUX=1

# It may help you reduce audio latency further, tweak values in case it breaks
# https://gist.github.com/cidkidnix/86a01ecf82f54eec39f27a9807b90a1b
# export PULSE_LATENCY_MSEC=10
# https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Configuration?version_id=25749f548c1e2fddd9e1678d9b7e57ebfcae3cf2#setting-buffer-size
# export PIPEWIRE_LATENCY=256/48000

# Disable new media source implementation
# May help fix potential audio issues with the new implementation
# export PROTON_AUDIO_CONVERT=0
# export PROTON_AUDIO_CONVERT_BIN=0
# export PROTON_VIDEO_CONVERT=0
# export PROTON_DEMUX=0

# Disable logs
# May help reduce resource usage
export PROTON_LOG=0
export WINEDEBUG=-all
export KD3D_DEBUG=none
export VKD3D_SHADER_DEBUG=none
