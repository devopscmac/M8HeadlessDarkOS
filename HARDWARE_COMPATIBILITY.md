# Hardware Compatibility

## Primary Target: R36S Plus

| Component | Specification | Notes |
|-----------|--------------|-------|
| **SoC** | PK3326 (Rockchip RK3326-equivalent) | Confirmed via product page "PK3326 processor" |
| **CPU** | Quad-core ARM Cortex-A35, 64-bit (ARMv8-A) | Up to ~1.5 GHz |
| **GPU** | Mali-G31 MP2 | OpenGL ES 3.2, driver: `libmali-bifrost-g31-rxp0-gbm.so` |
| **RAM** | ~1 GB DDR3L | Standard for RK3326 class devices |
| **Display** | 4.0" IPS, **720×720** (1:1 square) | Unique feature vs standard R36S (640×480) |
| **Storage** | MicroSD, 64GB included | 2nd SD slot may or may not be present |
| **Audio** | RK817 PMIC + integrated codec | ALSA device: `rockchiprk817co` |
| **Controls** | Dual analog sticks, D-pad, A/B/X/Y, L1/R1/L2/R2, Start/Select | GO-Super Gamepad compatible |
| **Connectivity** | WiFi (AP6212 or similar), Bluetooth, USB-C (OTG), HDMI | |
| **Battery** | ~3000–4000mAh, 8–12h rated | |
| **OS shipped** | Batocera Linux | Confirms Linux/ARM64 compatibility |

### Display Note

The 720×720 square display is the key hardware difference from other RK3326
devices. This affects:

- **EmulationStation**: configured for 1:1 aspect ratio (not 4:3)
- **RetroArch**: uses integer scaling with black borders for 4:3 content
- **m8c**: M8's native 320×240 display is scaled 2× to 640×480, centered in
  the 720×720 frame with 40px borders top/bottom

## M8 Headless Hardware

To use M8 Headless mode, you need one of:

### Option A: Dirtywave M8 Hardware

| Item | Notes |
|------|-------|
| M8 Tracker (hardware) | Any revision with firmware 6.0.0+ |
| USB-C cable | M8 connects via USB-C |
| M8 firmware | Must support headless USB display mode |

The M8 appears as USB serial device (16c0:0483 or similar).
Udev symlink: `/dev/m8`

### Option B: Teensy 4.1 + M8 Headless Firmware

| Item | Notes |
|------|-------|
| PJRC Teensy 4.1 | Available from pjrc.com |
| M8 Headless firmware | https://github.com/Dirtywave/M8Firmware |
| USB-C cable | Teensy connects via USB |
| Audio adapter (optional) | For analog audio output from Teensy |

The Teensy appears as USB CDC serial device (16c0:0487).
Udev symlink: `/dev/m8headless`

## Kernel Device Tree

The R36S Plus requires a Linux device tree (DTB) that describes:

1. **Display panel**: 720×720 IPS panel (ST7703 or NV3051D controller)
2. **Input**: Analog sticks (ADC), digital buttons (GPIO), VBUS USB-C
3. **Audio**: RK817 codec (I2S), speaker amplifier
4. **PMIC**: RK817 power management
5. **Storage**: SD card host (RK3326 SDHCI)
6. **GPU**: Mali-G31 MP2

### DTB Status

- The existing `rk3326-g350-linux.dtb` / `rk3326-rg351mp-linux.dtb` from
  dArkOS are close matches but may need panel definition updates for 720×720
- The display panel entry must match the actual LCD controller on the R36S Plus
- Recommend examining `/sys/class/drm/` and kernel dmesg after first boot to
  identify the exact panel driver

### Panel Identification

After first boot, identify the panel:
```bash
# Check kernel messages for panel driver
dmesg | grep -i "panel\|drm\|mipi\|dsi\|NV3051\|ST7703"

# Check DRM connector info
cat /sys/class/drm/card0-DSI-1/status 2>/dev/null
```

## Related Hardware (Tested by dArkOS)

If the R36S Plus DTB is not yet mature, these dArkOS-supported devices share
the same SoC family and can use their configurations as a starting point:

| Device | UNIT | Display | Notes |
|--------|------|---------|-------|
| G350 | g350 | 320×240 (RK3326) | Closest build target |
| RG351MP | rg351mp | 480×320 (RK3326) | Same kernel branch |
| A10 Mini | a10mini | 320×480 (RK3326) | Same GPU driver |
| RGB10 | rgb10 | 320×480 (RK3326) | Different U-Boot |

## Performance Expectations on R36S Plus

| Application | Expected Performance |
|------------|---------------------|
| m8c (M8 display mirror) | 60fps native, minimal CPU overhead |
| RetroArch (NES/SNES/GBA) | Full speed |
| RetroArch (PSX) | Full speed with pcsx_rearmed |
| RetroArch (N64) | ~60fps with mupen64plus_next |
| DuckStation (PS1) | Good performance |
| Mupen64Plus (N64) | Good performance |
| PPSSPP (PSP) | Moderate; depends on game |

The RK3326 is a well-understood SoC in the retro gaming community with
mature driver support in the dArkOS ecosystem.
