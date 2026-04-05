#!/bin/bash
# =============================================================================
# launch_m8c.sh — M8 Headless client launcher for R36S Plus
# =============================================================================

M8C_BIN="/opt/m8c/bin/m8c"
M8C_CONFIG="/home/ark/.local/share/m8c/config.ini"
M8C_LOG="/tmp/m8c.log"
GPU_ADDR="ff400000"

{
echo "==> M8 Headless: Starting $(date)..."

# ---------------------------------------------------------------------------
# Check m8c binary exists
# ---------------------------------------------------------------------------
if [ ! -x "${M8C_BIN}" ]; then
  echo "ERROR: m8c binary not found at ${M8C_BIN}"
  sleep 3
  exit 1
fi

echo "==> Library check:"
ldd "${M8C_BIN}" 2>&1

# ---------------------------------------------------------------------------
# Detect M8 / Teensy device
# ---------------------------------------------------------------------------
echo "==> Serial devices:"
ls -la /dev/ttyACM* /dev/m8* /dev/teensy* 2>&1

M8_DEVICE=""
if [ -e "/dev/m8" ]; then
  M8_DEVICE="/dev/m8"
elif [ -e "/dev/m8headless" ]; then
  M8_DEVICE="/dev/m8headless"
elif [ -e "/dev/ttyACM0" ]; then
  M8_DEVICE="/dev/ttyACM0"
elif [ -e "/dev/ttyUSB0" ]; then
  M8_DEVICE="/dev/ttyUSB0"
fi

echo "==> M8 device: ${M8_DEVICE:-not found, m8c will auto-detect}"

# ---------------------------------------------------------------------------
# Performance mode
# ---------------------------------------------------------------------------
echo performance | sudo tee /sys/devices/platform/${GPU_ADDR}.gpu/devfreq/${GPU_ADDR}.gpu/governor > /dev/null 2>&1 || true
echo performance | sudo tee /sys/devices/system/cpu/cpufreq/policy0/scaling_governor > /dev/null 2>&1 || true
echo performance | sudo tee /sys/devices/platform/dmc/devfreq/dmc/governor > /dev/null 2>&1 || true

# Ensure ark has serial port access
if ! groups ark 2>/dev/null | grep -q dialout; then
  sudo usermod -a -G dialout ark
fi

export SDL_AUDIODRIVER=alsa
export SDL_GAMECONTROLLERCONFIG_FILE="/opt/m8c/bin/gamecontrollerdb.txt"

# ---------------------------------------------------------------------------
# Launch m8c — try SDL video drivers in order until one works
# ---------------------------------------------------------------------------
EXIT_CODE=1
for DRIVER in kmsdrm offscreen; do
  echo "==> Trying SDL_VIDEODRIVER=${DRIVER}..."
  export SDL_VIDEODRIVER="${DRIVER}"
  "${M8C_BIN}" 2>&1
  EXIT_CODE=$?
  echo "==> m8c exited (code=${EXIT_CODE}, driver=${DRIVER})"
  [ "${EXIT_CODE}" -eq 0 ] && break
  sleep 1
done

# ---------------------------------------------------------------------------
# Restore normal performance mode
# ---------------------------------------------------------------------------
echo ondemand | sudo tee /sys/devices/platform/${GPU_ADDR}.gpu/devfreq/${GPU_ADDR}.gpu/governor > /dev/null 2>&1 || true
echo ondemand | sudo tee /sys/devices/system/cpu/cpufreq/policy0/scaling_governor > /dev/null 2>&1 || true
echo ondemand | sudo tee /sys/devices/platform/dmc/devfreq/dmc/governor > /dev/null 2>&1 || true

echo "==> M8 Headless: Done (exit ${EXIT_CODE}). Log: ${M8C_LOG}"
[ "${EXIT_CODE}" != "0" ] && sleep 3

exit ${EXIT_CODE}

} 2>&1 | tee "${M8C_LOG}"
