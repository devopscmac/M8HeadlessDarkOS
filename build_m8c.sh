#!/bin/bash
# =============================================================================
# build_m8c.sh — Build m8c (M8 Headless client) inside the ARM64 chroot
# =============================================================================
# m8c is the client application for the Dirtywave M8 Tracker in headless mode.
# It connects to the M8 or a Teensy running M8 Headless firmware via USB serial,
# mirrors the M8 display, and routes audio/input.
#
# This script:
#   1. Installs build deps (SDL3, libserialport) inside Arkbuild chroot
#   2. Clones/copies m8c source into chroot
#   3. Compiles m8c for ARM64
#   4. Installs binary + config to /opt/m8c/
#   5. Installs systemd user service and launcher script
#   6. Copies device-specific config (r36splus mappings)
# =============================================================================

echo "==> build_m8c: Starting M8 Headless client build..."

M8C_INSTALL_DIR="Arkbuild/opt/m8c"
M8C_CHROOT_SRC="/home/ark/m8c_build"
M8C_VERSION="2.2.4"

# Determine cache path
M8C_CACHE="Arkbuild_package_cache/${CHIPSET}/m8c_${M8C_VERSION}.tar.gz"

# Check if we have a cached build
if [ -f "${M8C_CACHE}" ]; then
  echo "==> build_m8c: Found cached m8c binary, extracting..."
  sudo tar -xzf "${M8C_CACHE}" -C Arkbuild/
  echo "==> build_m8c: Cached m8c installed successfully."
else
  echo "==> build_m8c: No cache found, building m8c from source..."

  # ---------------------------------------------------------------------------
  # Step 1: Install build dependencies inside ARM64 chroot
  # ---------------------------------------------------------------------------
  echo "==> build_m8c: Installing build dependencies..."

  # Update chroot apt first (may already be done, idempotent)
  sudo chroot Arkbuild/ bash -c "apt-get update -qq" || true

  # Install SDL3 build dependencies inside the ARM64 chroot.
  # install_package expects an arch specifier as $1 ("32", "armhf", or anything
  # else → :arm64), with packages in $2+. Passing a package name as $1 silently
  # skips it and treats it as the arch selector.
  install_package arm64 \
    libsdl3-dev \
    libserialport-dev \
    libusb-1.0-0-dev \
    libudev-dev \
    cmake \
    build-essential \
    pkg-config \
    git

  # ---------------------------------------------------------------------------
  # Step 2: Copy m8c source into chroot (from host M8C_REPO)
  # ---------------------------------------------------------------------------
  echo "==> build_m8c: Copying m8c source into chroot..."
  sudo mkdir -p "Arkbuild${M8C_CHROOT_SRC}"

  # Copy the m8c source tree into the chroot
  # We use rsync to exclude .git history to keep things clean
  sudo rsync -a --exclude='.git' --exclude='build' \
    "${M8C_REPO}/" "Arkbuild${M8C_CHROOT_SRC}/"

  # ---------------------------------------------------------------------------
  # Step 3: Build m8c inside the ARM64 chroot
  # ---------------------------------------------------------------------------
  echo "==> build_m8c: Compiling m8c (ARM64, libserialport backend)..."

  sudo chroot Arkbuild/ bash -c "
    set -e
    cd ${M8C_CHROOT_SRC}

    # Clean any prior build
    rm -rf build_arm64

    # Configure with cmake
    # USE_LIBSERIALPORT=ON  : standard serial backend (works with /dev/ttyACM*)
    # USE_LIBUSB=OFF        : disable direct USB (less compatible)
    # USE_RTMIDI=OFF        : not using MIDI backend
    cmake -S . -B build_arm64 \
      -DCMAKE_BUILD_TYPE=Release \
      -DUSE_LIBSERIALPORT=ON \
      -DUSE_LIBUSB=OFF \
      -DUSE_RTMIDI=OFF \
      -DCMAKE_EXE_LINKER_FLAGS="-Wl,--no-as-needed -Wl,--allow-shlib-undefined"

    # Build using all available cores
    cmake --build build_arm64 --parallel \$(nproc)

    echo 'Build complete, binary at: build_arm64/m8c'
    ls -la build_arm64/m8c
  "
  verify_action

  # ---------------------------------------------------------------------------
  # Step 4: Install m8c into /opt/m8c/ inside the image
  # ---------------------------------------------------------------------------
  echo "==> build_m8c: Installing m8c to /opt/m8c/..."

  sudo mkdir -p "${M8C_INSTALL_DIR}/bin"
  sudo mkdir -p "${M8C_INSTALL_DIR}/config"

  # Copy the compiled binary
  sudo cp "Arkbuild${M8C_CHROOT_SRC}/build_arm64/m8c" \
          "${M8C_INSTALL_DIR}/bin/m8c"
  sudo chmod 755 "${M8C_INSTALL_DIR}/bin/m8c"

  # Copy gamecontrollerdb.txt (SDL gamepad mappings database)
  sudo cp "Arkbuild${M8C_CHROOT_SRC}/gamecontrollerdb.txt" \
          "${M8C_INSTALL_DIR}/bin/gamecontrollerdb.txt"

  # Copy device-specific m8c configuration for R36S Plus
  sudo cp "device/${UNIT}/m8c.ini" \
          "${M8C_INSTALL_DIR}/config/config.ini"

  # Create a symlink so m8c is accessible from PATH
  sudo chroot Arkbuild/ bash -c "ln -sfv /opt/m8c/bin/m8c /usr/local/bin/m8c"

  # ---------------------------------------------------------------------------
  # Step 5: Install launcher script and systemd service
  # ---------------------------------------------------------------------------
  echo "==> build_m8c: Installing m8c launcher and services..."

  # Main launcher script
  sudo cp "scripts/launch_m8c.sh" "${M8C_INSTALL_DIR}/launch_m8c.sh"
  sudo chmod 755 "${M8C_INSTALL_DIR}/launch_m8c.sh"
  sudo chroot Arkbuild/ bash -c "ln -sfv /opt/m8c/launch_m8c.sh /usr/local/bin/launch_m8c"

  # M8 device auto-connect helper (udev rules)
  sudo cp "scripts/m8c_setup.sh" "Arkbuild/usr/local/bin/m8c_setup"
  sudo chmod 755 "Arkbuild/usr/local/bin/m8c_setup"

  # Install udev rule so the M8/Teensy gets correct permissions automatically
  cat <<'UDEV_EOF' | sudo tee Arkbuild/etc/udev/rules.d/99-m8-headless.rules > /dev/null
# Dirtywave M8 Tracker (USB serial)
SUBSYSTEM=="tty", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="0483", \
  SYMLINK+="m8", GROUP="dialout", MODE="0664", TAG+="systemd"

# Teensy 4.1 running M8 Headless firmware
SUBSYSTEM=="tty", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="0487", \
  SYMLINK+="m8headless", GROUP="dialout", MODE="0664", TAG+="systemd"

# Generic Teensy (M8 Headless fallback)
SUBSYSTEM=="tty", ATTRS{idVendor}=="16c0", \
  SYMLINK+="teensy", GROUP="dialout", MODE="0664"
UDEV_EOF

  # Add ark user to dialout group for serial port access
  sudo chroot Arkbuild/ bash -c "usermod -a -G dialout ark"

  # ---------------------------------------------------------------------------
  # Step 6: Cache the build for future rebuilds
  # ---------------------------------------------------------------------------
  echo "==> build_m8c: Caching m8c build..."
  sudo tar -czf "${M8C_CACHE}" \
    -C Arkbuild/ \
    opt/m8c/ \
    usr/local/bin/m8c \
    usr/local/bin/launch_m8c \
    usr/local/bin/m8c_setup \
    etc/udev/rules.d/99-m8-headless.rules

  echo "==> build_m8c: Build cached at ${M8C_CACHE}"
fi

# ---------------------------------------------------------------------------
# Verify installation
# ---------------------------------------------------------------------------
if [ -f "Arkbuild/opt/m8c/bin/m8c" ]; then
  echo "==> build_m8c: SUCCESS — m8c installed at /opt/m8c/bin/m8c"
  file "Arkbuild/opt/m8c/bin/m8c" 2>/dev/null || true
else
  echo "==> build_m8c: ERROR — m8c binary not found after build!"
  exit 1
fi

echo "==> build_m8c: Done."
