#!/bin/bash
# =============================================================================
# m8c_setup.sh — First-time M8 Headless setup helper for R36S Plus
# =============================================================================
# Run this script once after first boot to:
#   1. Verify m8c installation
#   2. Test USB serial device detection
#   3. Configure audio output
#   4. Test gamepad mappings
#   5. Create user config from template if missing
# =============================================================================

M8C_BIN="/opt/m8c/bin/m8c"
M8C_CONFIG_DIR="/home/ark/.local/share/m8c"
M8C_CONFIG="${M8C_CONFIG_DIR}/config.ini"
M8C_TEMPLATE="/opt/m8c/config/config.ini"

echo ""
echo "=============================================="
echo " M8HeadlessDarkOS — M8 Headless Setup"
echo "=============================================="
echo ""

# ---------------------------------------------------------------------------
# 1. Check m8c binary
# ---------------------------------------------------------------------------
echo "[1/5] Checking m8c installation..."
if [ -x "${M8C_BIN}" ]; then
  echo "  OK: m8c found at ${M8C_BIN}"
  file "${M8C_BIN}" 2>/dev/null | sed 's/^/       /'
else
  echo "  ERROR: m8c binary not found at ${M8C_BIN}"
  echo "  Please rebuild M8HeadlessDarkOS."
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Check/create user config
# ---------------------------------------------------------------------------
echo ""
echo "[2/5] Checking m8c configuration..."
mkdir -p "${M8C_CONFIG_DIR}"
if [ ! -f "${M8C_CONFIG}" ]; then
  if [ -f "${M8C_TEMPLATE}" ]; then
    cp "${M8C_TEMPLATE}" "${M8C_CONFIG}"
    echo "  OK: Created config from template at ${M8C_CONFIG}"
  else
    echo "  WARNING: No config template found. m8c will use defaults."
  fi
else
  echo "  OK: Config exists at ${M8C_CONFIG}"
fi

# ---------------------------------------------------------------------------
# 3. Check USB device detection
# ---------------------------------------------------------------------------
echo ""
echo "[3/5] Checking M8/Teensy USB device..."
M8_FOUND=0

for DEV in /dev/m8 /dev/m8headless /dev/ttyACM0 /dev/ttyACM1 /dev/ttyUSB0; do
  if [ -e "${DEV}" ]; then
    echo "  FOUND: ${DEV}"
    ls -la "${DEV}" | sed 's/^/         /'
    M8_FOUND=1
    break
  fi
done

if [ "${M8_FOUND}" -eq "0" ]; then
  echo "  NOT FOUND: No M8 or Teensy detected"
  echo "  Connect your M8 tracker or Teensy (M8 Headless firmware) via USB-C"
fi

# Check dialout group membership
echo ""
if groups ark 2>/dev/null | grep -q dialout; then
  echo "  OK: User 'ark' has dialout group access (serial ports)"
else
  echo "  FIXING: Adding 'ark' to dialout group..."
  sudo usermod -a -G dialout ark
  echo "  NOTE: Log out and back in for group change to take effect"
fi

# ---------------------------------------------------------------------------
# 4. Check audio
# ---------------------------------------------------------------------------
echo ""
echo "[4/5] Checking audio..."
if aplay -l 2>/dev/null | grep -q "card"; then
  echo "  OK: ALSA audio devices found:"
  aplay -l 2>/dev/null | grep "card" | sed 's/^/       /'
else
  echo "  WARNING: No ALSA audio devices found"
fi

# Check if PulseAudio is running (optional but helpful for audio routing)
if pgrep -x pulseaudio &>/dev/null; then
  echo "  OK: PulseAudio is running"
elif pgrep -x pipewire &>/dev/null; then
  echo "  OK: PipeWire is running"
fi

# ---------------------------------------------------------------------------
# 5. Udev rules check
# ---------------------------------------------------------------------------
echo ""
echo "[5/5] Checking udev rules..."
UDEV_RULES="/etc/udev/rules.d/99-m8-headless.rules"
if [ -f "${UDEV_RULES}" ]; then
  echo "  OK: M8 udev rules installed at ${UDEV_RULES}"
else
  echo "  WARNING: M8 udev rules not found"
  echo "  Installing..."
  cat <<'UDEV_EOF' | sudo tee "${UDEV_RULES}" > /dev/null
# Dirtywave M8 Tracker
SUBSYSTEM=="tty", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="0483", \
  SYMLINK+="m8", GROUP="dialout", MODE="0664"
# Teensy 4.1 (M8 Headless)
SUBSYSTEM=="tty", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="0487", \
  SYMLINK+="m8headless", GROUP="dialout", MODE="0664"
UDEV_EOF
  sudo udevadm control --reload-rules
  sudo udevadm trigger
  echo "  OK: udev rules installed and reloaded"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=============================================="
echo " Setup Complete"
echo "=============================================="
echo ""
echo "To launch M8 Headless:"
echo "  From EmulationStation: Tools > M8 Headless"
echo "  From BaRT menu:        Option 3"
echo "  From terminal:         /opt/m8c/launch_m8c.sh"
echo ""
echo "Documentation: /opt/m8c/README.md"
echo ""
