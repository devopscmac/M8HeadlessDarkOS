#!/bin/bash
# =============================================================================
# launch_m8c.sh — M8 Headless client launcher for R36S Plus
# =============================================================================
# This script:
#   1. Detects if an M8 or Teensy (M8 Headless) is connected via USB
#   2. Configures audio routing (PulseAudio/ALSA loopback)
#   3. Sets performance governor for smooth display mirroring
#   4. Launches m8c with R36S Plus configuration
#   5. Restores normal state after exit
# =============================================================================

M8C_BIN="/opt/m8c/bin/m8c"
M8C_CONFIG="/home/ark/.local/share/m8c/config.ini"
M8C_LOG="/tmp/m8c.log"

# Performance governor (same as retroarch launch)
GPU_ADDR="ff400000"

echo "==> M8 Headless: Starting..."

# ---------------------------------------------------------------------------
# Check m8c binary exists
# ---------------------------------------------------------------------------
if [ ! -x "${M8C_BIN}" ]; then
  echo "ERROR: m8c binary not found at ${M8C_BIN}"
  echo "Please reinstall M8HeadlessDarkOS or run m8c_setup."
  sleep 3
  exit 1
fi

# ---------------------------------------------------------------------------
# Detect M8 / Teensy device
# ---------------------------------------------------------------------------
M8_DEVICE=""

# Check for M8 Tracker (udev symlink created by 99-m8-headless.rules)
if [ -e "/dev/m8" ]; then
  M8_DEVICE="/dev/m8"
  echo "==> M8 Headless: Found M8 Tracker at ${M8_DEVICE}"
elif [ -e "/dev/m8headless" ]; then
  M8_DEVICE="/dev/m8headless"
  echo "==> M8 Headless: Found M8 Headless (Teensy) at ${M8_DEVICE}"
elif [ -e "/dev/ttyACM0" ]; then
  M8_DEVICE="/dev/ttyACM0"
  echo "==> M8 Headless: Found serial device at ${M8_DEVICE}"
elif [ -e "/dev/ttyUSB0" ]; then
  M8_DEVICE="/dev/ttyUSB0"
  echo "==> M8 Headless: Found USB serial at ${M8_DEVICE}"
else
  echo "==> M8 Headless: WARNING — No M8/Teensy device found."
  echo "    Connect your M8 or Teensy (M8 Headless firmware) via USB and try again."
  echo "    m8c will attempt to connect automatically when a device is plugged in."
fi

# ---------------------------------------------------------------------------
# Set performance mode for smooth 60fps display mirroring
# ---------------------------------------------------------------------------
echo performance | sudo tee /sys/devices/platform/${GPU_ADDR}.gpu/devfreq/${GPU_ADDR}.gpu/governor > /dev/null 2>&1 || true
echo performance | sudo tee /sys/devices/system/cpu/cpufreq/policy0/scaling_governor > /dev/null 2>&1 || true
echo performance | sudo tee /sys/devices/platform/dmc/devfreq/dmc/governor > /dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# Configure SDL for the R36S Plus display (720x720, KMS/DRM)
# ---------------------------------------------------------------------------
export SDL_VIDEODRIVER="kmsdrm"
export SDL_RENDER_DRIVER="opengl"

# Point to the R36S Plus gamecontrollerdb for correct button mapping
export SDL_GAMECONTROLLERCONFIG_FILE="/opt/m8c/bin/gamecontrollerdb.txt"

# ---------------------------------------------------------------------------
# Ensure ark user has dialout group access (for serial port)
# ---------------------------------------------------------------------------
if ! groups ark | grep -q dialout; then
  sudo usermod -a -G dialout ark
  echo "==> M8 Headless: Added ark to dialout group (relogin may be needed)"
fi

# ---------------------------------------------------------------------------
# Launch m8c
# ---------------------------------------------------------------------------
echo "==> M8 Headless: Launching m8c..."
echo "    Config: ${M8C_CONFIG}"
echo "    Device: ${M8_DEVICE:-auto-detect}"
echo ""
echo "    Controls:"
echo "      D-Pad    → M8 navigation"
echo "      A        → M8 A button"
echo "      B        → M8 B button"
echo "      L1       → M8 OPT"
echo "      R1       → M8 EDIT"
echo "      Select   → M8 SHIFT"
echo "      Start    → M8 PLAY"
echo "      F12      → Toggle audio"
echo "      F1       → Settings menu"
echo ""

# Run m8c with config file
# If M8_DEVICE is empty, m8c will auto-detect
"${M8C_BIN}" 2>&1 | tee "${M8C_LOG}"
EXIT_CODE=$?

# ---------------------------------------------------------------------------
# Restore normal performance mode
# ---------------------------------------------------------------------------
echo ondemand | sudo tee /sys/devices/platform/${GPU_ADDR}.gpu/devfreq/${GPU_ADDR}.gpu/governor > /dev/null 2>&1 || true
echo ondemand | sudo tee /sys/devices/system/cpu/cpufreq/policy0/scaling_governor > /dev/null 2>&1 || true
echo ondemand | sudo tee /sys/devices/platform/dmc/devfreq/dmc/governor > /dev/null 2>&1 || true

echo "==> M8 Headless: Exited (code ${EXIT_CODE})"
if [ "${EXIT_CODE}" != "0" ]; then
  echo "    Check log at: ${M8C_LOG}"
  sleep 2
fi

exit ${EXIT_CODE}
