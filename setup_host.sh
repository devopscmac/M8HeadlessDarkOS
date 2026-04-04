#!/bin/bash
# =============================================================================
# setup_host.sh — Install all host dependencies for M8HeadlessDarkOS
# =============================================================================
# Run this ONCE on a fresh Ubuntu/Debian host before building.
# Requires sudo access.
#
# Usage:
#   bash setup_host.sh           (install everything + build m8c binary)
#   bash setup_host.sh --m8c-only  (skip dArkOS tools, only build m8c)
# =============================================================================

set -euo pipefail

MODE="${1:-full}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M8C_REPO="${M8C_REPO:-$(dirname "${SCRIPT_DIR}")/m8c}"
OUTPUT_BIN="${SCRIPT_DIR}/bin/m8c-r36splus"

# Sysroot where we install arm64 libs built from source
AARCH64_SYSROOT="/opt/aarch64-sysroot"

echo "============================================================"
echo " M8HeadlessDarkOS Host Setup"
echo " Ubuntu/Debian x86_64 required"
echo "============================================================"
echo ""

# ---------------------------------------------------------------------------
# 1. Core build tools
# ---------------------------------------------------------------------------
echo "[1/5] Installing core build tools..."
sudo apt-get update -qq
sudo apt-get install -y \
  bc btrfs-progs build-essential bison flex ccache curl \
  debconf-utils debootstrap device-tree-compiler dosfstools \
  e2fsprogs eatmydata gcc gdisk jq p7zip-full parted \
  python-is-python3 qemu-user-static xfsprogs rsync git wget \
  gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
  cmake ninja-build pkg-config autoconf automake libtool \
  lib32stdc++6 libc6-i386 libncurses5-dev libssl-dev lz4 lzop \
  2>/dev/null || true

echo "  OK: $(aarch64-linux-gnu-gcc --version | head -1)"
echo "  OK: $(cmake --version | head -1)"

# ---------------------------------------------------------------------------
# 2. apt-cacher-ng (dArkOS build cache — skipped in --m8c-only mode)
# ---------------------------------------------------------------------------
if [ "${MODE}" != "--m8c-only" ]; then
  echo ""
  echo "[2/5] Setting up apt-cacher-ng build cache..."
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
else
  echo "[2/5] Skipping apt-cacher-ng (--m8c-only)"
fi

# ---------------------------------------------------------------------------
# 3. Build SDL3 from source for aarch64
#    SDL3 is not reliably available as a cross-compile package on Ubuntu.
#    We build it ourselves and install to AARCH64_SYSROOT.
# ---------------------------------------------------------------------------
echo ""
echo "[3/5] Building SDL3 for aarch64..."

SDL3_TAG="release-3.2.14"
SDL3_SRC="/tmp/SDL3_src"
SDL3_BUILD="/tmp/SDL3_build_aarch64"

if [ -f "${AARCH64_SYSROOT}/lib/pkgconfig/sdl3.pc" ]; then
  echo "  OK: SDL3 already built (found ${AARCH64_SYSROOT}/lib/pkgconfig/sdl3.pc)"
  echo "  (To force a rebuild: sudo rm -rf ${AARCH64_SYSROOT} and re-run)"
else
  echo "  Cloning SDL3 ${SDL3_TAG}..."
  rm -rf "${SDL3_SRC}" "${SDL3_BUILD}"
  git clone --depth=1 --branch "${SDL3_TAG}" \
    https://github.com/libsdl-org/SDL.git "${SDL3_SRC}"

  echo "  Configuring SDL3 for aarch64 (KMS/DRM backend, no X11/Wayland)..."
  cmake -S "${SDL3_SRC}" -B "${SDL3_BUILD}" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
    -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_INSTALL_PREFIX="${AARCH64_SYSROOT}" \
    -DSDL_SHARED=ON \
    -DSDL_STATIC=OFF \
    -DSDL_KMSDRM=ON \
    -DSDL_X11=OFF \
    -DSDL_WAYLAND=OFF \
    -DSDL_DIRECTFB=OFF \
    -DSDL_OPENGL=OFF \
    -DSDL_OPENGLES=ON \
    -DSDL_VULKAN=OFF \
    -DSDL_TESTS=OFF \
    -DSDL_EXAMPLES=OFF \
    -DSDL_UNIX_CONSOLE_BUILD=ON

  echo "  Compiling SDL3 ($(nproc) cores)..."
  cmake --build "${SDL3_BUILD}" --parallel "$(nproc)"
  sudo cmake --install "${SDL3_BUILD}"
  echo "  OK: SDL3 installed to ${AARCH64_SYSROOT}"
fi

# ---------------------------------------------------------------------------
# 4. Build libserialport from source for aarch64
# ---------------------------------------------------------------------------
echo ""
echo "[4/5] Building libserialport for aarch64..."

SERIALPORT_SRC="/tmp/libserialport_src"

if [ -f "${AARCH64_SYSROOT}/lib/pkgconfig/libserialport.pc" ]; then
  echo "  OK: libserialport already built"
else
  echo "  Cloning libserialport..."
  rm -rf "${SERIALPORT_SRC}"
  git clone --depth=1 \
    https://github.com/sigrokproject/libserialport.git "${SERIALPORT_SRC}"

  cd "${SERIALPORT_SRC}"
  ./autogen.sh
  CC=aarch64-linux-gnu-gcc \
    ./configure --host=aarch64-linux-gnu \
                --prefix="${AARCH64_SYSROOT}" \
                --enable-shared \
                --disable-static
  make -j"$(nproc)"
  sudo make install
  cd "${SCRIPT_DIR}"
  echo "  OK: libserialport installed to ${AARCH64_SYSROOT}"
fi

# ---------------------------------------------------------------------------
# 5. Cross-compile m8c for aarch64 using the sysroot
# ---------------------------------------------------------------------------
echo ""
echo "[5/5] Building m8c for aarch64 (R36S Plus)..."

if [ ! -d "${M8C_REPO}" ]; then
  echo "  ERROR: m8c repo not found at ${M8C_REPO}"
  echo "  Clone it with: git clone https://github.com/laamaa/m8c.git $(dirname "${M8C_REPO}")/m8c"
  exit 1
fi

M8C_BUILD="${M8C_REPO}/build_aarch64_host"
rm -rf "${M8C_BUILD}"

echo "  Configuring m8c..."
PKG_CONFIG_PATH="${AARCH64_SYSROOT}/lib/pkgconfig" \
cmake -S "${M8C_REPO}" -B "${M8C_BUILD}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
  -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
  -DCMAKE_PREFIX_PATH="${AARCH64_SYSROOT}" \
  -DCMAKE_FIND_ROOT_PATH="${AARCH64_SYSROOT}" \
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_EXE_LINKER_FLAGS="-L${AARCH64_SYSROOT}/lib -Wl,-rpath-link,${AARCH64_SYSROOT}/lib" \
  -DUSE_LIBSERIALPORT=ON \
  -DUSE_LIBUSB=OFF \
  -DUSE_RTMIDI=OFF

echo "  Compiling m8c ($(nproc) cores)..."
cmake --build "${M8C_BUILD}" --parallel "$(nproc)"

if [ -f "${M8C_BUILD}/m8c" ]; then
  cp "${M8C_BUILD}/m8c" "${OUTPUT_BIN}"
  echo ""
  echo "  SUCCESS: m8c binary built and saved to bin/m8c-r36splus"
  file "${OUTPUT_BIN}"
  ls -lh "${OUTPUT_BIN}"
else
  echo "  ERROR: m8c binary not found after build — check output above"
  exit 1
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " Setup Complete"
echo "============================================================"
echo "  ARM64 gcc:     OK ($(aarch64-linux-gnu-gcc --version | head -1 | awk '{print $NF}'))"
echo "  SDL3:          OK (${AARCH64_SYSROOT}/lib/pkgconfig/sdl3.pc)"
echo "  libserialport: OK (${AARCH64_SYSROOT}/lib/pkgconfig/libserialport.pc)"
echo "  m8c binary:    OK (${OUTPUT_BIN})"
echo "  qemu-static:   $(which qemu-aarch64-static 2>/dev/null && echo OK || echo MISSING)"
echo "  debootstrap:   $(which debootstrap 2>/dev/null && echo OK || echo MISSING)"
echo ""
echo "Next steps:"
echo "  git add bin/m8c-r36splus"
echo "  git commit -m 'Add precompiled m8c ARM64 binary for R36S Plus'"
echo "  make r36splus   (full OS build)"
echo ""
