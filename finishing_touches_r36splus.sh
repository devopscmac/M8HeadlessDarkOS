#!/bin/bash
# =============================================================================
# finishing_touches_r36splus.sh — R36S Plus post-build configuration
# =============================================================================
# Applies device-specific configuration to the built rootfs for R36S Plus.
# This extends the dArkOS RK3326 finishing touches with:
#   - 720x720 display configuration
#   - M8 Headless / m8c EmulationStation entry
#   - R36S Plus-specific audio, controls, and service setup
# =============================================================================

echo "==> finishing_r36splus: Applying R36S Plus device configuration..."

# We source the base RK3326 finishing touches from dArkOS first
# This sets up boot.ini, audio, hotkeydaemon, etc.
source "${DARKOS_DIR}/finishing_touches.sh"

# ---------------------------------------------------------------------------
# Override: hostname = r36splus
# ---------------------------------------------------------------------------
echo "r36splus" | sudo tee Arkbuild/etc/hostname > /dev/null
sudo sed -i "s/127.0.1.1.*/127.0.1.1\tr36splus/" Arkbuild/etc/hosts

# Record device identity for runtime scripts
echo "R36SPLUS" | sudo tee Arkbuild/home/ark/.config/.DEVICE > /dev/null

# ---------------------------------------------------------------------------
# Display: 720x720 — EmulationStation configuration
# ---------------------------------------------------------------------------
echo "==> finishing_r36splus: Installing ES configs for 720x720 display..."

sudo mkdir -p Arkbuild/home/ark/.emulationstation/

# ES settings (720x720 display, square screen)
sudo cp "Emulationstation/es_settings.cfg.r36splus" \
        Arkbuild/home/ark/.emulationstation/es_settings.cfg

# ES input configuration (R36S Plus gamepad mappings)
sudo cp "Emulationstation/es_input.cfg.r36splus" \
        Arkbuild/home/ark/.emulationstation/es_input.cfg

# ES systems config (RK3326-based, includes m8c system entry)
sudo cp "Emulationstation/es_systems.cfg.r36splus" \
        Arkbuild/etc/emulationstation/es_systems.cfg

# ES launch script for R36S Plus
sudo cp "Emulationstation/emulationstation.sh.r36splus" \
        Arkbuild/usr/bin/emulationstation/emulationstation.sh
sudo chmod 755 Arkbuild/usr/bin/emulationstation/emulationstation.sh

sudo chroot Arkbuild/ bash -c "chown -R ark:ark /home/ark/.emulationstation/"

# ---------------------------------------------------------------------------
# RetroArch: R36S Plus display configuration
# ---------------------------------------------------------------------------
echo "==> finishing_r36splus: Configuring RetroArch for 720x720..."

# RetroArch needs to know the video dimensions for the 720x720 square display
RETROARCH_CFG="Arkbuild/home/ark/.config/retroarch/retroarch.cfg"
if [ -f "${RETROARCH_CFG}" ]; then
  # Set video output dimensions for the square display
  sudo sed -i 's/video_fullscreen_x = .*/video_fullscreen_x = "720"/' "${RETROARCH_CFG}" 2>/dev/null || true
  sudo sed -i 's/video_fullscreen_y = .*/video_fullscreen_y = "720"/' "${RETROARCH_CFG}" 2>/dev/null || true
fi

# Copy R36S Plus specific retroarch config additions
if [ -f "device/${UNIT}/retroarch.cfg" ]; then
  sudo cp "device/${UNIT}/retroarch.cfg" \
          "Arkbuild/home/ark/.config/retroarch/retroarch.cfg.${UNIT}"
fi

# ---------------------------------------------------------------------------
# M8 Headless: Create /roms/m8c directory for M8 patches/samples
# ---------------------------------------------------------------------------
echo "==> finishing_r36splus: Setting up M8 Headless directories..."

sudo mkdir -p Arkbuild/roms/m8c
sudo chroot Arkbuild/ bash -c "chown ark:ark /roms/m8c"

# Create m8c data directory in ark home
sudo mkdir -p Arkbuild/home/ark/.local/share/m8c
sudo chroot Arkbuild/ bash -c "chown -R ark:ark /home/ark/.local/share/m8c"

# Copy the default m8c config for R36S Plus
sudo mkdir -p Arkbuild/home/ark/.local/share/m8c/
sudo cp "device/${UNIT}/m8c.ini" \
        Arkbuild/home/ark/.local/share/m8c/config.ini
sudo chroot Arkbuild/ bash -c "chown ark:ark /home/ark/.local/share/m8c/config.ini"

# ---------------------------------------------------------------------------
# M8 Headless: Add to system tools menu
# ---------------------------------------------------------------------------
echo "==> finishing_r36splus: Adding M8 Headless launcher to system tools..."

sudo mkdir -p "Arkbuild/opt/system/Tools"

# Create the M8 Headless launcher shortcut in the tools menu
cat <<'LAUNCHER_EOF' | sudo tee Arkbuild/opt/system/Tools/M8\ Headless.sh > /dev/null
#!/bin/bash
# Launch M8 Headless client
# Requires M8 tracker or Teensy with M8 Headless firmware connected via USB

/opt/m8c/launch_m8c.sh
LAUNCHER_EOF
sudo chmod 755 "Arkbuild/opt/system/Tools/M8 Headless.sh"

# ---------------------------------------------------------------------------
# M8 Headless: Add EmulationStation system entry for M8 ROMs
# ---------------------------------------------------------------------------
# This creates a dedicated "M8 Music Tracker" section in EmulationStation
# where users can store M8 project files (.m8s, .m8i) for reference
sudo mkdir -p Arkbuild/roms/m8c
cat <<'M8README_EOF' | sudo tee "Arkbuild/roms/m8c/README.txt" > /dev/null
M8 Music Tracker — Headless Mode
=================================

This folder is for M8 Tracker project files and instruments.
To use M8 Headless:

1. Connect your M8 tracker or Teensy (M8 Headless firmware) via USB-C
2. Launch "M8 Headless" from the Tools menu, or
3. Select any item from this list in EmulationStation

M8 Headless connects automatically to /dev/m8 or /dev/ttyACM0.

Controls (R36S Plus):
  D-Pad    → M8 Navigation
  A        → M8 A (edit/confirm)
  B        → M8 B (back/delete char)
  L1       → M8 OPT (option modifier)
  R1       → M8 EDIT (edit mode)
  Select   → M8 SHIFT (hold for shift commands)
  Start    → M8 PLAY (play/stop)

Audio:
  M8 audio is routed through SDL audio to the R36S Plus speaker/headphones.
  Enable in m8c: press F12, or toggle in Settings > Audio.

For more info: https://github.com/laamaa/m8c
M8README_EOF
sudo chroot Arkbuild/ bash -c "chown -R ark:ark /roms/m8c"

# ---------------------------------------------------------------------------
# Bluetooth: Enable for R36S Plus (has BT hardware)
# ---------------------------------------------------------------------------
if [[ "${BUILD_BLUEALSA}" == "y" ]]; then
  echo "==> finishing_r36splus: Configuring Bluetooth..."
  if [ -f "${DARKOS_DIR}/build_bluealsa.sh" ]; then
    source "${DARKOS_DIR}/build_bluealsa.sh"
  fi
fi

# ---------------------------------------------------------------------------
# Version file: record build metadata
# ---------------------------------------------------------------------------
cat <<EOF | sudo tee Arkbuild/etc/m8headlessdarkos_version > /dev/null
M8HeadlessDarkOS
Version: ${M8HEADLESS_VERSION:-1.0.0}
Device: R36S Plus (PK3326/RK3326)
Display: 720x720
Build date: ${BUILD_DATE}
Debian: ${DEBIAN_CODE_NAME:-trixie}
EOF

sudo chroot Arkbuild/ bash -c "chown root:root /etc/m8headlessdarkos_version"

# ---------------------------------------------------------------------------
# Boot partition: verify and finalize
# ---------------------------------------------------------------------------
# dArkOS finishing_touches.sh writes boot.ini and does a lazy umount, but:
#   1. It uses root=/dev/mmcblk0p2 (fragile) — we want LABEL=ROOTFS
#   2. It copies logos/ which doesn't exist in this repo, so it may bail early
#   3. Lazy umount (-l) can leave writes unflushed before losetup -d
#
# We remount the boot partition here (if needed), overwrite boot.ini with
# correct values, sync, and do a proper umount + losetup detach.
# ---------------------------------------------------------------------------
echo "==> finishing_r36splus: Verifying boot partition..."

# Re-attach the boot loop device if it was already detached
if ! mountpoint -q "${mountpoint}" 2>/dev/null; then
  echo "==> finishing_r36splus: Boot partition not mounted, reattaching..."
  BOOT_PART_OFFSET=$((SYSTEM_PART_START * 512))
  BOOT_PART_SIZE=$(( (SYSTEM_PART_END - SYSTEM_PART_START + 1) * 512 ))
  LOOP_BOOT=$(sudo losetup --find --show \
    --offset ${BOOT_PART_OFFSET} \
    --sizelimit ${BOOT_PART_SIZE} \
    ${DISK})
  sudo mount ${LOOP_BOOT} ${mountpoint}
fi

# Verify kernel files; for DTB, fall back to odroidgo3 if r36splus-specific one is absent
# (the rg351 kernel branch has odroidgo3 DTS which matches R36S Plus hardware)
for f in Image uInitrd; do
  if [ ! -f "${mountpoint}/${f}" ]; then
    echo "==> finishing_r36splus: WARNING — ${f} missing from boot partition!"
  else
    echo "==> finishing_r36splus: OK — ${f} ($(ls -lh ${mountpoint}/${f} | awk '{print $5}'))"
  fi
done

# DTB: use r36splus if present, otherwise use odroidgo3 (same hardware base)
DTB_TARGET="${mountpoint}/rk3326-r36sPlus-linux.dtb"
if [ -f "${mountpoint}/${KERNEL_DTB}" ] && [ "${KERNEL_DTB}" != "rk3326-r36sPlus-linux.dtb" ]; then
  sudo cp "${mountpoint}/${KERNEL_DTB}" "${DTB_TARGET}"
  echo "==> finishing_r36splus: OK — DTB copied from ${KERNEL_DTB} to rk3326-r36sPlus-linux.dtb"
elif [ -f "${DTB_TARGET}" ]; then
  echo "==> finishing_r36splus: OK — rk3326-r36sPlus-linux.dtb already present"
else
  # Try odroidgo3 fallback from kernel build dir
  ODROIDGO3_DTB="${KERNEL_SRC}/arch/arm64/boot/dts/rockchip/rk3326-odroidgo3-linux.dtb"
  if [ -f "${ODROIDGO3_DTB}" ]; then
    sudo cp "${ODROIDGO3_DTB}" "${DTB_TARGET}"
    echo "==> finishing_r36splus: OK — DTB: used odroidgo3 fallback (same hardware)"
  else
    echo "==> finishing_r36splus: WARNING — no suitable DTB found for boot partition!"
  fi
fi

# Write boot.ini — use LABEL=ROOTFS (reliable) and correct DTB filename
echo "==> finishing_r36splus: Writing boot.ini..."
sudo tee "${mountpoint}/boot.ini" > /dev/null << BOOTINI_EOF
odroidgoa-uboot-config

# M8HeadlessDarkOS — R36S Plus
setenv bootargs "root=LABEL=ROOTFS rootwait rw fsck.repair=yes net.ifnames=0 fbcon=rotate:${SCREEN_ROTATION} console=/dev/ttyFIQ0 quiet splash consoleblank=0 vt.global_cursor_default=0"

setenv loadaddr "0x02000000"
setenv initrd_loadaddr "0x04000000"
setenv dtb_loadaddr "0x01f00000"

load mmc 1:1 \${loadaddr} Image
load mmc 1:1 \${initrd_loadaddr} uInitrd
load mmc 1:1 \${dtb_loadaddr} rk3326-r36sPlus-linux.dtb

booti \${loadaddr} \${initrd_loadaddr} \${dtb_loadaddr}
BOOTINI_EOF

echo "==> finishing_r36splus: Boot partition contents:"
ls -lh "${mountpoint}/"

# Sync all writes, then do a clean unmount and loop detach
sync
sudo umount "${mountpoint}"
sudo losetup -d ${LOOP_BOOT}
echo "==> finishing_r36splus: Boot partition finalized and unmounted."

echo "==> finishing_r36splus: R36S Plus device configuration complete."
