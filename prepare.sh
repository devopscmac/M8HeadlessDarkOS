#!/bin/bash
# =============================================================================
# prepare.sh — Host build environment check for M8HeadlessDarkOS
# =============================================================================
# Extends dArkOS's prepare.sh with m8c-specific host dependencies.
# Must be sourced AFTER utils.sh (provides verify_action).
# =============================================================================

echo "==> prepare: Checking M8HeadlessDarkOS build environment..."

# Run the base dArkOS prepare (installs debootstrap, qemu, etc.)
source "${DARKOS_DIR}/prepare.sh"

# ---------------------------------------------------------------------------
# Additional host tools needed for m8c integration
# ---------------------------------------------------------------------------
echo "==> prepare: Checking m8c host dependencies..."

M8C_HOST_TOOLS=(
  "rsync"
  "cmake"
  "pkg-config"
)

for TOOL in "${M8C_HOST_TOOLS[@]}"; do
  if ! command -v "${TOOL}" &>/dev/null; then
    echo "==> prepare: Installing ${TOOL}..."
    sudo apt -y install "${TOOL}"
    verify_action
  fi
done

# Verify m8c source is available
if [ ! -f "${M8C_REPO}/CMakeLists.txt" ]; then
  echo "ERROR: m8c CMakeLists.txt not found at ${M8C_REPO}/CMakeLists.txt"
  echo "Set M8C_REPO=<path> to the m8c repository"
  exit 1
fi

# ---------------------------------------------------------------------------
# Verify dArkOS linaro toolchain is available (needed for kernel build)
# ---------------------------------------------------------------------------
if [ ! -d "/opt/toolchains/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu" ]; then
  echo "==> prepare: Linaro toolchain not found, cloning..."
  sudo mkdir -p /opt/toolchains/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu
  git clone --depth=1 \
    https://github.com/christianhaitian/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu.git \
    /opt/toolchains/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu
  verify_action
fi

echo "==> prepare: All build dependencies satisfied."
