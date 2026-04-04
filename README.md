# M8HeadlessDarkOS

A custom build of [DarkOS](https://github.com/christianhaitian/arkos) for the **R36S Plus** handheld gaming device, with the [m8c](https://github.com/laamaa/m8c) M8 Headless client pre-compiled and integrated as a first-class application.

## What is this?

**M8HeadlessDarkOS** = DarkOS (full ARM64 Linux gaming OS) + M8 Headless client

- **DarkOS** is a Debian-based ARM64 Linux distribution optimized for retro gaming on handheld devices using Rockchip SoCs. It includes EmulationStation, RetroArch, and dozens of standalone emulators.
- **m8c** is the official remote display client for the [Dirtywave M8 Tracker](https://dirtywave.com/). It connects to a real M8 hardware unit or a [Teensy 4.1 running M8 Headless firmware](https://github.com/Dirtywave/M8Firmware) via USB, mirrors the M8 display, and routes audio.
- **R36S Plus** is a handheld gaming device with a PK3326 SoC (RK3326-equivalent), 4.0" 720x720 IPS display, and dual analog sticks.

## Hardware Requirements

| Component | Specification |
|-----------|--------------|
| Device | R36S Plus |
| SoC | PK3326 (Rockchip RK3326-equivalent) |
| CPU | Quad-core ARM Cortex-A35, 64-bit |
| GPU | Mali-G31 MP2 |
| Display | 4.0" IPS, 720x720 (1:1 square) |
| Storage | MicroSD (8GB minimum, 32GB+ recommended) |
| Connectivity | WiFi, Bluetooth, USB-C, HDMI |

For M8 Headless, you also need:
- A **Dirtywave M8 Tracker** (hardware), OR
- A **Teensy 4.1** running [M8 Headless firmware](https://github.com/Dirtywave/M8Firmware)
- A USB-C to USB-C cable (or USB-C to USB-A adapter)

## Quick Start

### Building the OS Image

```bash
# Clone the repository and navigate here
cd /path/to/M8HeadlessDarkOS

# Build for R36S Plus (takes 3–19 hours depending on caching)
make r36splus

# Or with options
ENABLE_CACHE=n BUILD_ARMHF=n make r36splus
```

See [BUILD_GUIDE.md](BUILD_GUIDE.md) for detailed build instructions, caching setup, and troubleshooting.

### Flashing to SD Card

After the build completes:

```bash
# The image will be: M8HeadlessDarkOS_r36splus_<date>.img.7z
# Extract and flash:
7z e M8HeadlessDarkOS_r36splus_*.img.7z
sudo dd if=M8HeadlessDarkOS_r36splus_*.img of=/dev/sdX bs=4M status=progress
sync
```

Replace `/dev/sdX` with your SD card device (check with `lsblk`).

### Using M8 Headless

1. Boot your R36S Plus with the M8HeadlessDarkOS SD card
2. Connect your M8 or Teensy (M8 Headless) via USB-C
3. From the main menu, press **Select** to open BaRT → choose **M8 Headless**
   — OR —
   Navigate to **Tools → M8 Headless** in EmulationStation

### M8 Controls (R36S Plus)

| Physical Button | M8 Function |
|----------------|-------------|
| D-Pad           | Navigation  |
| A button        | A (select/confirm) |
| B button        | B (back/cancel) |
| L1 (left shoulder) | OPT (modifier) |
| R1 (right shoulder) | EDIT (edit mode) |
| Select | SHIFT (hold for shift commands) |
| Start | PLAY (play/stop sequencer) |
| F12 (keyboard) | Toggle audio routing |
| F1 (keyboard)  | m8c settings menu |

## Repository Structure

```
M8HeadlessDarkOS/
├── Makefile                       # Build system entry point
├── build_r36splus.sh              # Main build orchestrator
├── build_m8c.sh                   # m8c compilation step
├── prepare.sh                     # Host dependency checker
├── finishing_touches_r36splus.sh  # R36S Plus device configuration
│
├── device/
│   └── r36splus/
│       ├── m8c.ini                # m8c config for R36S Plus
│       └── retroarch.cfg          # RetroArch overrides for 720x720
│
├── Emulationstation/
│   ├── es_settings.cfg.r36splus   # ES display settings
│   ├── es_input.cfg.r36splus      # Gamepad input mappings
│   ├── es_systems.cfg.r36splus    # Game systems + M8C entry
│   └── emulationstation.sh.r36splus  # ES launcher (includes M8 in BaRT)
│
├── scripts/
│   ├── launch_m8c.sh              # M8C launcher (sets performance mode, etc.)
│   └── m8c_setup.sh               # First-time setup helper
│
├── bin/
│   └── m8c-r36splus               # Precompiled m8c binary (ARM64)
│
├── local_repos/                   # Local git mirrors for offline builds
│   └── README.md
│
├── tests/                         # Automated test suite
│   ├── run_all_tests.sh
│   ├── test_build_scripts.sh
│   ├── test_device_config.sh
│   ├── test_m8c_binary.sh
│   └── test_emulationstation.sh
│
├── README.md                      # This file
├── ARCHITECTURE.md                # Technical architecture
├── BUILD_GUIDE.md                 # Detailed build instructions
├── HARDWARE_COMPATIBILITY.md      # Hardware details and compatibility
└── CHANGELOG.md                   # Version history
```

## Build Options

| Variable | Default | Description |
|---------|---------|-------------|
| `DEBIAN_CODE_NAME` | `trixie` | Debian release to use |
| `ENABLE_CACHE` | `y` | Use apt-cacher-ng to speed up rebuilds |
| `BUILD_ARMHF` | `y` | Include 32-bit ARM userspace (some emulators need it) |
| `BUILD_BLUEALSA` | `y` | Include Bluetooth audio support |
| `DARKOS_DIR` | `../dArkOS` | Path to the dArkOS repository |
| `M8C_REPO` | `../m8c` | Path to the m8c source repository |

## Relationship to dArkOS

This project uses dArkOS's build system as its foundation. The `build_r36splus.sh`
script sources most build steps directly from `../dArkOS/` and adds:

1. A new device target (`r36splus`, UNIT=r36splus, CHIPSET=rk3326)
2. The `build_m8c.sh` step that compiles m8c inside the ARM64 chroot
3. R36S Plus device files (720x720 display configs, m8c.ini)
4. M8C integration in EmulationStation (new `m8c` system entry, BaRT menu option)

No modifications are made to the dArkOS repository itself, so it can be updated
independently.

## Running Tests

```bash
make test
# or directly:
bash tests/run_all_tests.sh
```

Tests validate build script syntax, device configurations, ES configs, and
(if present) the precompiled m8c binary.

## Troubleshooting

**m8c can't find the M8 device:**
```bash
# Check for the device
ls -la /dev/ttyACM* /dev/m8 /dev/m8headless 2>/dev/null

# Make sure ark is in dialout group
groups ark | grep dialout
sudo usermod -a -G dialout ark  # then relogin
```

**Audio not working in m8c:**
- Press F12 inside m8c to toggle audio
- Check m8c.ini has `audio_enabled = true`
- The M8 must be in headless mode (display connected before plugging in USB)

**Display is black after launching m8c:**
- Verify `SDL_VIDEODRIVER=kmsdrm` is set in launch_m8c.sh
- Check `/tmp/m8c.log` for errors

**Build fails with "dArkOS not found":**
```bash
# Set the correct path
DARKOS_DIR=/path/to/dArkOS make r36splus
```

## Credits

- **DarkOS** by Christian Haitian (christianhaitian) — base OS and build system
- **m8c** by laamaa — M8 Headless client
- **Dirtywave** — M8 Tracker hardware and headless firmware
- **Libretro / RetroArch** — emulation framework

## License

M8HeadlessDarkOS build scripts: MIT License

Components have their own licenses:
- dArkOS: see `../dArkOS/LICENSES.md`
- m8c: see `../m8c/LICENSE` (MIT)
- RetroArch: GPLv3
- Individual emulator cores: various open source licenses
