#!/bin/bash
# =============================================================================
# setup_host.sh — Install all host dependencies for M8HeadlessDarkOS
# =============================================================================
# Run this ONCE on a fresh Ubuntu/Debian host before building.
# Requires sudo access.
#
# Usage:
#   bash setup_host.sh           (install all dependencies)
#   bash setup_host.sh --m8c-only  (install only m8c cross-compilation tools)
# =============================================================================

set -euo pipefail

MODE="${1:-full}"

echo "============================================================"
echo " M8HeadlessDarkOS Host Setup"
echo " Ubuntu/Debian x86_64 required"
echo "============================================================"
echo ""

# ---------------------------------------------------------------------------
# 1. Core build tools (required for dArkOS build pipeline)
# ---------------------------------------------------------------------------
echo "[1/4] Installing core build tools..."
sudo apt-get update -qq
sudo apt-get install -y \
  bc btrfs-progs build-essential bison flex ccache curl \
  debconf-utils debootstrap device-tree-compiler dosfstools \
  e2fsprogs eatmydata gcc gdisk jq p7zip-full parted \
  python-is-python3 qemu-user-static xfsprogs rsync \
  lib32stdc++6 libc6-i386 libncurses5-dev libssl-dev lz4 lzop \
  zlib1g:i386 2>/dev/null || true

echo "  OK: Core build tools installed"

if [ "${MODE}" == "--m8c-only" ]; then
  echo "[1/4] Skipping dArkOS-specific tools (--m8c-only)"
else
  # ---------------------------------------------------------------------------
  # 2. Optional: apt-cacher-ng for build caching
  # ---------------------------------------------------------------------------
  echo ""
  echo "[2/4] Setting up apt-cacher-ng build cache..."
  if ! apt list --installed 2>/dev/null | grep -q apt-cacher-ng; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y apt-cacher-ng
    sudo sed -i "/\# AllowUserPorts:/c\AllowUserPorts: 0" /etc/apt-cacher-ng/acng.conf
    sudo sed -i "/\# DlMaxRetries: /c\DlMaxRetries: 50000" /etc/apt-cacher-ng/acng.conf
    sudo sed -i "/\# VfileUseRangeOps: /c\VfileUseRangeOps: 0" /etc/apt-cacher-ng/acng.conf
    sudo systemctl enable --now apt-cacher-ng
    echo "  OK: apt-cacher-ng installed and enabled"
  else
    echo "  OK: apt-cacher-ng already installed"
  fi
fi

# ---------------------------------------------------------------------------
# 3. ARM64 cross-compilation tools (for standalone m8c build)
# ---------------------------------------------------------------------------
echo ""
echo "[3/4] Installing ARM64 cross-compilation tools..."

# Add arm64 foreign architecture
sudo dpkg --add-architecture arm64

sudo apt-get update -qq

# Cross-compiler
sudo apt-get install -y \
  gcc-aarch64-linux-gnu \
  g++-aarch64-linux-gnu \
  cmake \
  pkg-config

echo "  OK: ARM64 cross-compiler installed"
echo "  $(aarch64-linux-gnu-gcc --version | head -1)"

# Try to install arm64 SDL3 dev libraries
echo ""
echo "  Attempting to install arm64 dev libraries..."

# Add [arch=arm64] variant of Ubuntu ports for arm64
if ! grep -r "ports.ubuntu.com" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null | grep -q arm64; then
  echo "  Adding Ubuntu ports for arm64..."
  UBUNTU_CODENAME=$(lsb_release -cs 2>/dev/null || echo "questing")
  cat <<EOF | sudo tee /etc/apt/sources.list.d/ubuntu-arm64-ports.list > /dev/null
deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports ${UBUNTU_CODENAME} main restricted universe multiverse
deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports ${UBUNTU_CODENAME}-security main restricted universe multiverse
EOF
  sudo apt-get update -qq
fi

# Try SDL3 arm64 (Ubuntu 25.10 should have it)
if sudo apt-get install -y libsdl3-dev:arm64 2>/dev/null; then
  echo "  OK: libsdl3-dev:arm64 installed"
  SDL3_AVAILABLE=y
else
  echo "  INFO: libsdl3-dev:arm64 not available; SDL3 will be built from source during OS build"
  SDL3_AVAILABLE=n
fi

# Try libserialport arm64
if sudo apt-get install -y libserialport-dev:arm64 2>/dev/null; then
  echo "  OK: libserialport-dev:arm64 installed"
  SERIALPORT_AVAILABLE=y
else
  echo "  INFO: libserialport-dev:arm64 not available; will be installed inside chroot during OS build"
  SERIALPORT_AVAILABLE=n
fi

# ---------------------------------------------------------------------------
# 4. Standalone m8c cross-compilation (if arm64 libs available)
# ---------------------------------------------------------------------------
echo ""
echo "[4/4] Building m8c for ARM64 (R36S Plus)..."

M8C_REPO="${M8C_REPO:-$(dirname "$(pwd)")/m8c}"
OUTPUT_BIN="bin/m8c-r36splus"

if [ ! -d "${M8C_REPO}" ]; then
  echo "  SKIP: m8c repo not found at ${M8C_REPO}"
  echo "  Set M8C_REPO=<path> to build m8c standalone"
elif [ "${SDL3_AVAILABLE}" != "y" ] || [ "${SERIALPORT_AVAILABLE}" != "y" ]; then
  echo "  SKIP: arm64 dev libraries not available for standalone build"
  echo "  m8c will be compiled during the full OS build (make r36splus)"
else
  echo "  Building m8c for aarch64..."
  cd "${M8C_REPO}"
  rm -rf build_aarch64_host
  cmake -S . -B build_aarch64_host \
    -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
    -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_FIND_ROOT_PATH=/usr/aarch64-linux-gnu \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DUSE_LIBSERIALPORT=ON \
    -DUSE_LIBUSB=OFF \
    -DUSE_RTMIDI=OFF \
    -DCMAKE_BUILD_TYPE=Release

  cmake --build build_aarch64_host --parallel "$(nproc)"

  # Copy to M8HeadlessDarkOS bin/
  PROJ_DIR="$(dirname "${M8C_REPO}")/M8HeadlessDarkOS"
  if [ -f "build_aarch64_host/m8c" ]; then
    cp build_aarch64_host/m8c "${PROJ_DIR}/${OUTPUT_BIN}"
    echo ""
    echo "  SUCCESS: m8c ARM64 binary built!"
    file "${PROJ_DIR}/${OUTPUT_BIN}"
    echo "  Saved to: ${PROJ_DIR}/${OUTPUT_BIN}"
  else
    echo "  ERROR: m8c binary not found after build"
  fi
  cd -
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " Setup Summary"
echo "============================================================"
echo "  Core tools:     installed"
echo "  ARM64 gcc:      $(which aarch64-linux-gnu-gcc 2>/dev/null && echo 'OK' || echo 'MISSING')"
echo "  cmake:          $(which cmake 2>/dev/null && echo 'OK' || echo 'MISSING')"
echo "  qemu-static:    $(which qemu-aarch64-static 2>/dev/null && echo 'OK' || echo 'MISSING')"
echo "  debootstrap:    $(which debootstrap 2>/dev/null && echo 'OK' || echo 'MISSING')"
echo "  SDL3 arm64:     ${SDL3_AVAILABLE:-n}"
echo "  serialport arm64: ${SERIALPORT_AVAILABLE:-n}"
echo ""
echo "To build M8HeadlessDarkOS:"
echo "  cd M8HeadlessDarkOS"
echo "  make r36splus"
echo ""
