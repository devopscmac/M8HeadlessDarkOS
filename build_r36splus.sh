#!/bin/bash
# =============================================================================
# M8HeadlessDarkOS — R36S Plus Build Script
# =============================================================================
# Target Hardware : R36S Plus (PK3326 / RK3326-equivalent, 720x720 IPS)
# Base System     : DarkOS (Debian Trixie, ARM64)
# Extra           : M8 Headless client (m8c) pre-compiled and integrated
# =============================================================================
# Usage:
#   ./build_r36splus.sh                (normal build)
#   ENABLE_CACHE=n ./build_r36splus.sh (no apt-cacher-ng)
#   BUILD_ARMHF=n ./build_r36splus.sh  (64-bit only)
# =============================================================================

# Rotate build logs
if [ -f "build.log" ]; then
  ext=1
  while true; do
    if [ -f "build.log.${ext}" ]; then
      let ext=ext+1
    else
      mv build.log "build.log.${ext}"
      break
    fi
  done
fi

(
set -euo pipefail

# ---------------------------------------------------------------------------
# Device Configuration — R36S Plus
# ---------------------------------------------------------------------------
export CHIPSET=rk3326
export UNIT=r36splus
export SCREEN_ROTATION=0
export KERNEL_DTB="rk3326-r36splus-linux.dtb"
export ROOT_FILESYSTEM_FORMAT=btrfs
export ROOT_FILESYSTEM_MOUNT_OPTIONS="defaults,compress=zlib,noatime"

# Display configuration (720x720 square IPS panel)
export DISPLAY_WIDTH=720
export DISPLAY_HEIGHT=720
export DISPLAY_BPP=32

# M8HeadlessDarkOS-specific exports
export M8HEADLESS_VERSION="1.0.0"
export DARKOS_DIR="${DARKOS_DIR:-../dArkOS}"
export M8C_REPO="${M8C_REPO:-../m8c}"

# Validate required repos are present
if [ ! -d "${DARKOS_DIR}" ]; then
  echo "ERROR: dArkOS not found at ${DARKOS_DIR}"
  echo "Set DARKOS_DIR=<path> or run from the Repos/headless directory"
  exit 1
fi

if [ ! -d "${M8C_REPO}" ]; then
  echo "ERROR: m8c repo not found at ${M8C_REPO}"
  echo "Set M8C_REPO=<path> or run from the Repos/headless directory"
  exit 1
fi

echo "=================================================================="
echo " M8HeadlessDarkOS Build Starting"
echo "  CHIPSET  : ${CHIPSET}"
echo "  UNIT     : ${UNIT}"
echo "  Display  : ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
echo "  Debian   : ${DEBIAN_CODE_NAME:-trixie}"
echo "  dArkOS   : ${DARKOS_DIR}"
echo "  m8c      : ${M8C_REPO}"
echo "=================================================================="

# ---------------------------------------------------------------------------
# Source the dArkOS utility functions
# ---------------------------------------------------------------------------
source "${DARKOS_DIR}/utils.sh"

# ---------------------------------------------------------------------------
# Build pipeline (mirrors dArkOS g350 build, adapted for R36S Plus + m8c)
# ---------------------------------------------------------------------------

# 1. Verify host build tools are present (uses dArkOS prepare.sh logic)
source ./prepare.sh

# 2. Set up disk image partitions
source "${DARKOS_DIR}/setup_partition.sh"

# 3. Bootstrap Debian ARM64 base system
source "${DARKOS_DIR}/bootstrap_rootfs.sh"

# 4. Configure image (filesystems, mount points, locales)
source "${DARKOS_DIR}/image_setup.sh"

# 5. Build Linux kernel for RK3326
source "${DARKOS_DIR}/build_kernel.sh"

# 6. Build GPU, RGA, and core libraries
source "${DARKOS_DIR}/build_deps.sh"

# 7. Build SDL2 (used by most emulators)
source "${DARKOS_DIR}/build_sdl2.sh"

# 8. Build emulators (same selection as g350)
source "${DARKOS_DIR}/build_ppssppsa.sh"
source "${DARKOS_DIR}/build_ppsspp-2021sa.sh"
source "${DARKOS_DIR}/build_duckstationsa.sh"
source "${DARKOS_DIR}/build_mupen64plussa.sh"
source "${DARKOS_DIR}/build_gzdoom.sh"
source "${DARKOS_DIR}/build_lzdoom.sh"
source "${DARKOS_DIR}/build_retroarch.sh"
source "${DARKOS_DIR}/build_retrorun.sh"
source "${DARKOS_DIR}/build_yabasanshirosa.sh"
source "${DARKOS_DIR}/build_mednafen.sh"
source "${DARKOS_DIR}/build_ecwolfsa.sh"
source "${DARKOS_DIR}/build_hypseus-singe.sh"
source "${DARKOS_DIR}/build_openbor.sh"
source "${DARKOS_DIR}/build_solarus.sh"
source "${DARKOS_DIR}/build_scummvmsa.sh"
source "${DARKOS_DIR}/build_fake08.sh"
source "${DARKOS_DIR}/build_xroar.sh"
source "${DARKOS_DIR}/build_mvem.sh"
source "${DARKOS_DIR}/build_bigpemu.sh"
source "${DARKOS_DIR}/build_ogage.sh"
source "${DARKOS_DIR}/build_ogacontrols.sh"
source "${DARKOS_DIR}/build_351files.sh"
source "${DARKOS_DIR}/build_filemanager.sh"
source "${DARKOS_DIR}/build_filebrowser.sh"
source "${DARKOS_DIR}/build_gptokeyb.sh"
source "${DARKOS_DIR}/build_image-viewer.sh"
source "${DARKOS_DIR}/build_emulationstation.sh"
source "${DARKOS_DIR}/build_linapple.sh"
source "${DARKOS_DIR}/build_applewinsa.sh"
source "${DARKOS_DIR}/build_piemu.sh"
source "${DARKOS_DIR}/build_ti99sim.sh"
source "${DARKOS_DIR}/build_gametank.sh"
source "${DARKOS_DIR}/build_openmsxsa.sh"
source "${DARKOS_DIR}/build_flycastsa.sh"
source "${DARKOS_DIR}/build_sdljoytest.sh"
source "${DARKOS_DIR}/build_controllertester.sh"
source "${DARKOS_DIR}/build_drastic.sh"

# 9. BUILD M8C — M8 Headless client (unique to M8HeadlessDarkOS)
echo ""
echo "=================================================================="
echo " Building m8c — M8 Headless client"
echo "=================================================================="
source ./build_m8c.sh

# 10. R36S Plus finishing touches (device-specific setup + m8c integration)
source ./finishing_touches_r36splus.sh

# 11. Remove build artifacts to shrink image
source "${DARKOS_DIR}/cleanup_filesystem.sh"

# 12. Write rootfs to disk image
source "${DARKOS_DIR}/write_rootfs.sh"

# 13. Unmount all loop devices
source "${DARKOS_DIR}/clean_mounts.sh"

# 14. Compress final image
source "${DARKOS_DIR}/create_image.sh"

echo ""
echo "=================================================================="
echo " M8HeadlessDarkOS R36S Plus build complete!"
echo " Final image: M8HeadlessDarkOS_r36splus_${BUILD_DATE}.img.7z"
echo "=================================================================="

) 2>&1 | tee -a build.log
