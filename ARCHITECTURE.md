# M8HeadlessDarkOS Architecture

## Overview

M8HeadlessDarkOS is an overlay build system on top of dArkOS. It does not fork
dArkOS; instead it sources dArkOS build scripts directly and extends them with:

1. A new device target (`r36splus`)
2. The m8c application build step
3. Device-specific configuration for 720x720 display
4. M8 Headless integration in EmulationStation

```
┌─────────────────────────────────────────────────────────┐
│                   M8HeadlessDarkOS                      │
│                                                         │
│  build_r36splus.sh ──► sources ──► ../dArkOS/*.sh       │
│        │                                                │
│        └──► build_m8c.sh ──► compiles inside chroot     │
│        └──► finishing_touches_r36splus.sh               │
│             (device config, ES integration, m8c paths)  │
└─────────────────────────────────────────────────────────┘
```

## Build Pipeline

The `build_r36splus.sh` script runs these stages in order:

```
Stage 1: prepare.sh
  - Installs host build tools (debootstrap, qemu, cmake, etc.)
  - Downloads Linaro ARM64 cross-compiler toolchain
  - Verifies dArkOS and m8c repos are accessible

Stage 2: setup_partition.sh (from dArkOS)
  - Creates a 7.8GB sparse disk image
  - Partitions with MBR (RK3326 style):
      Part 1: FAT32 boot (100MB)
      Part 2: btrfs root (7500MB)
      Part 3: FAT32 roms (300MB)

Stage 3: bootstrap_rootfs.sh (from dArkOS)
  - Bootstraps Debian Trixie ARM64 via debootstrap + qemu-aarch64-static
  - Caches the base rootfs tarball for faster rebuilds
  - Adds armhf (32-bit) multiarch if BUILD_ARMHF=y

Stage 4: image_setup.sh (from dArkOS)
  - Configures chroot: locales, apt sources, base packages

Stage 5: build_kernel.sh (from dArkOS)
  - Builds Linux kernel for RK3326 using Linaro cross-compiler
  - DTB: rk3326-r36splus-linux.dtb (device tree for R36S Plus)
  - Kernel branch: rg351 (from christianhaitian/linux)

Stage 6: build_deps.sh (from dArkOS)
  - Installs Mali-G31 GPU libraries (libmali-bifrost-g31-rxp0-gbm.so)
  - Builds librga (hardware accelerated image operations)
  - Builds libgo2 (Odroid Go / RK3326 hardware abstraction)

Stage 7: build_sdl2.sh (from dArkOS)
  - Compiles SDL2 optimized for RK3326 with KMS/DRM backend

Stages 8–N: Emulator builds (from dArkOS)
  - ppsspp, duckstation, mupen64plus, retroarch, mednafen, etc.
  - Uses build caches in Arkbuild_package_cache/rk3326/

Stage N+1: build_m8c.sh (NEW — M8HeadlessDarkOS specific)
  - Installs SDL3, libserialport inside ARM64 chroot
  - Copies m8c source from M8C_REPO into chroot
  - Compiles m8c with cmake (libserialport backend)
  - Installs to /opt/m8c/
  - Creates /etc/udev/rules.d/99-m8-headless.rules
  - Adds ark user to dialout group

Stage N+2: finishing_touches_r36splus.sh (NEW — M8HeadlessDarkOS specific)
  - Calls base finishing_touches.sh (boot.ini, audio, hotkeydaemon, etc.)
  - Overrides hostname to r36splus
  - Installs 720x720 ES configurations
  - Creates /roms/m8c/ directory
  - Installs m8c config to ~/.local/share/m8c/config.ini
  - Adds M8 Headless to Tools menu
  - Adds m8c entry to es_systems.cfg

Stage N+3: cleanup, write_rootfs, clean_mounts, create_image (from dArkOS)
  - Optimizes btrfs filesystem
  - Writes to disk image
  - Compresses to .img.7z
```

## Directory Layout (in produced OS image)

```
/
├── boot/                          # FAT32 boot partition
│   ├── boot.ini                   # U-Boot configuration
│   ├── Image                      # ARM64 kernel image
│   ├── uInitrd                    # Initial ramdisk
│   └── rk3326-r36splus-linux.dtb  # Device tree blob
│
├── opt/
│   ├── m8c/                       # M8 Headless client
│   │   ├── bin/
│   │   │   ├── m8c                # Compiled binary (ARM64)
│   │   │   └── gamecontrollerdb.txt
│   │   ├── config/
│   │   │   └── config.ini         # Default config (R36S Plus mapping)
│   │   └── launch_m8c.sh          # Launcher script
│   │
│   ├── retroarch/                 # RetroArch
│   │   ├── bin/retroarch
│   │   └── cores/                 # Libretro cores
│   │
│   └── system/
│       ├── Tools/
│       │   ├── M8 Headless.sh     # Quick launch shortcut
│       │   └── ...
│       └── ...
│
├── roms/                          # Game storage (mounts from FAT/exFAT partition)
│   ├── m8c/                       # M8 project files (reference storage)
│   ├── nes/
│   ├── snes/
│   └── ...
│
├── home/ark/
│   ├── .emulationstation/         # EmulationStation configs
│   │   ├── es_settings.cfg        # 720x720 display settings
│   │   └── es_input.cfg           # R36S Plus input mappings
│   └── .local/share/m8c/
│       └── config.ini             # Per-user m8c configuration
│
├── etc/
│   ├── emulationstation/
│   │   └── es_systems.cfg         # Systems list (includes m8c)
│   ├── udev/rules.d/
│   │   └── 99-m8-headless.rules   # USB device rules for M8/Teensy
│   └── m8headlessdarkos_version   # Build metadata
│
└── usr/local/bin/
    ├── m8c -> /opt/m8c/bin/m8c    # Symlink for PATH access
    ├── launch_m8c -> /opt/m8c/launch_m8c.sh
    └── m8c_setup                  # First-time setup helper
```

## m8c Communication Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      R36S Plus                               │
│                                                              │
│  ┌─────────────┐   USB serial    ┌──────────────────────┐    │
│  │    m8c      │◄───────────────►│   M8 Tracker (hw)    │    │
│  │  (ARM64)    │   /dev/ttyACM0  │      OR              │    │
│  │             │   /dev/m8       │  Teensy 4.1 +        │    │
│  └──────┬──────┘                 │  M8 Headless FW      │    │
│         │                        └──────────────────────┘    │
│         │ SDL3                                                │
│  ┌──────▼──────┐                                             │
│  │  KMS/DRM    │ → 720x720 display                           │
│  │   display   │                                             │
│  └─────────────┘                                             │
│         │ ALSA                                                │
│  ┌──────▼──────┐                                             │
│  │ R36S Plus   │ → Speaker / 3.5mm jack                      │
│  │   audio     │                                             │
│  └─────────────┘                                             │
└──────────────────────────────────────────────────────────────┘
```

**Communication protocol:**
- m8c sends: keypress events (directional, A, B, OPT, EDIT)  
- M8 sends:  display frames (320×240 pixels, 60fps), audio (USB audio class)
- Transport: USB CDC serial (libserialport backend) at ~460800 baud

## Key Technical Decisions

### 1. Device Target (r36splus vs g350)
The R36S Plus uses the same RK3326 SoC family as the G350 and RG351MP, but
has a 720×720 square display instead of 640×480. The `r36splus` device target
sets `DISPLAY_WIDTH=720` and `DISPLAY_HEIGHT=720`, and uses square-optimized
ES configurations.

### 2. m8c Backend: libserialport
Three backends are available in m8c:
- `libserialport` (selected): Works with standard /dev/ttyACM* paths. Most
  compatible on Linux embedded systems.
- `libusb`: More direct USB access, useful if serial enumeration fails.
- `rtmidi`: MIDI protocol, only for specialized M8 Headless setups.

libserialport is the safest default for the R36S Plus.

### 3. SDL3 for m8c
m8c 2.x uses SDL3 (not SDL2). SDL3 is installed inside the ARM64 chroot
from Debian Trixie packages, which as of 2025 include SDL3.

### 4. dArkOS as Non-Fork
dArkOS build scripts are sourced directly from `../dArkOS/` rather than
copied. This means:
- dArkOS can be updated independently (`git pull` in dArkOS dir)
- Bug fixes to dArkOS automatically benefit M8HeadlessDarkOS
- The only risk is API changes to dArkOS build scripts (tracked in CHANGELOG)

### 5. Build Caching
The dArkOS caching system (`Arkbuild_package_cache/rk3326/`) stores:
- The bootstrapped Debian rootfs tarball
- Individual emulator build tarballs
- m8c build tarball (added by M8HeadlessDarkOS)

Cache key includes the dArkOS CHIPSET and component version, enabling
incremental rebuilds after code changes.

## Security Considerations

- The `ark` user runs with `sudo NOPASSWD: ALL` (standard for embedded gaming OS)
- Serial port access requires `dialout` group membership (configured automatically)
- Udev rules give `dialout` group ownership of M8/Teensy USB devices (mode 0664)
- SSH is installed but disabled by default
- The `HandlePowerKey=ignore` systemd setting delegates power button to the
  hotkey daemon
