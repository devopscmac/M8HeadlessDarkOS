# Changelog

All notable changes to M8HeadlessDarkOS are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [1.0.0] — 2026-04-04

### Added
- Initial release of M8HeadlessDarkOS
- Build system targeting R36S Plus (PK3326 / RK3326, 720×720 display)
- Based on dArkOS (Debian Trixie ARM64) build infrastructure
- **m8c integration**: M8 Headless client compiled inside ARM64 chroot
  - SDL3 backend
  - libserialport communication (works with /dev/ttyACM*)
  - Installs to /opt/m8c/bin/m8c
- **R36S Plus device target** (`CHIPSET=rk3326, UNIT=r36splus`)
  - 720×720 square display EmulationStation configuration
  - R36S Plus gamepad input mappings (GO-Super Gamepad compatible)
  - M8c control mappings pre-configured for R36S Plus buttons
- **EmulationStation integration**
  - M8C system entry in es_systems.cfg
  - "M8 Music Tracker" category with launch command
  - BaRT menu includes "M8 Headless" option (Option 3)
  - Tools menu shortcut: `/opt/system/Tools/M8 Headless.sh`
- **USB device management**
  - Udev rules: `/etc/udev/rules.d/99-m8-headless.rules`
  - Symlinks: /dev/m8 (hardware), /dev/m8headless (Teensy)
  - ark user auto-added to dialout group
- **Build infrastructure**
  - `Makefile` with r36splus, test, preflight, clean targets
  - `build_m8c.sh`: m8c compilation with build caching
  - `prepare.sh`: host dependency verification
  - `finishing_touches_r36splus.sh`: device configuration
- **Test suite** (`make test`)
  - `test_build_scripts.sh`: shell syntax and structure validation
  - `test_device_config.sh`: m8c.ini, ES configs, scripts validation
  - `test_m8c_binary.sh`: ARM64 binary validation
  - `test_emulationstation.sh`: ES configuration completeness
- **Documentation**
  - README.md: quick start and feature overview
  - ARCHITECTURE.md: technical design and build pipeline
  - BUILD_GUIDE.md: step-by-step build and cross-compilation guide
  - HARDWARE_COMPATIBILITY.md: R36S Plus hardware profile
  - CHANGELOG.md: this file
  - local_repos/README.md: offline mirror setup guide

### Known Limitations
- R36S Plus device tree blob (rk3326-r36splus-linux.dtb) needs verification
  against actual hardware; falls back to rk3326-rg351mp-linux.dtb
- m8c binary in bin/ is a placeholder; precompiled binary is produced during
  full OS build or standalone cross-compilation
- es_systems.cfg includes only representative systems (not the full ~130 system
  dArkOS list); extend by copying from dArkOS's es_systems.cfg.rk3326

### dArkOS Version Compatibility
- Tested against: dArkOS commit history as of 2026-04
- dArkOS scripts sourced: bootstrap_rootfs.sh, build_deps.sh, build_sdl2.sh,
  build_retroarch.sh, finishing_touches.sh, cleanup_filesystem.sh,
  write_rootfs.sh, clean_mounts.sh, create_image.sh, utils.sh
- Breaking changes in dArkOS (e.g., renamed scripts) will require updating
  build_r36splus.sh accordingly
