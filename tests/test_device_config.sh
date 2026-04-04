#!/bin/bash
# =============================================================================
# test_device_config.sh — Validate R36S Plus device configuration files
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

PASS=0
FAIL=0

ok()   { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
info() { echo "  INFO: $1"; }

echo "=== Device Configuration Validation ==="
echo ""

# ---------------------------------------------------------------------------
# Test 1: Device directory structure
# ---------------------------------------------------------------------------
echo "--- Device directory ---"

DEVICE_DIR="${PROJECT_DIR}/device/r36splus"
if [ -d "${DEVICE_DIR}" ]; then
  ok "device/r36splus directory exists"
else
  fail "device/r36splus directory MISSING"
fi

DEVICE_FILES=(
  "device/r36splus/m8c.ini"
  "device/r36splus/retroarch.cfg"
)

for f in "${DEVICE_FILES[@]}"; do
  if [ -f "${PROJECT_DIR}/${f}" ]; then
    ok "${f} exists"
    [ -s "${PROJECT_DIR}/${f}" ] && ok "${f} is non-empty" || fail "${f} is EMPTY"
  else
    fail "${f} MISSING"
  fi
done

# ---------------------------------------------------------------------------
# Test 2: m8c.ini validation
# ---------------------------------------------------------------------------
echo ""
echo "--- m8c.ini sections ---"

M8C_INI="${PROJECT_DIR}/device/r36splus/m8c.ini"
if [ -f "${M8C_INI}" ]; then
  for section in "[graphics]" "[audio]" "[keyboard]" "[gamepad]"; do
    if grep -q "${section}" "${M8C_INI}"; then
      ok "m8c.ini has section ${section}"
    else
      fail "m8c.ini missing section ${section}"
    fi
  done

  # Check for required settings
  grep -q "init_fullscreen" "${M8C_INI}" && ok "init_fullscreen setting present" || fail "init_fullscreen MISSING"
  grep -q "audio_enabled"   "${M8C_INI}" && ok "audio_enabled setting present"  || fail "audio_enabled MISSING"
  grep -q "key_up"          "${M8C_INI}" && ok "key_up mapping present"          || fail "key_up MISSING"
  grep -q "key_down"        "${M8C_INI}" && ok "key_down mapping present"        || fail "key_down MISSING"
fi

# ---------------------------------------------------------------------------
# Test 3: EmulationStation configs
# ---------------------------------------------------------------------------
echo ""
echo "--- EmulationStation configs ---"

ES_DIR="${PROJECT_DIR}/Emulationstation"
ES_FILES=(
  "es_settings.cfg.r36splus"
  "es_input.cfg.r36splus"
  "es_systems.cfg.r36splus"
  "emulationstation.sh.r36splus"
)

for f in "${ES_FILES[@]}"; do
  if [ -f "${ES_DIR}/${f}" ]; then
    ok "${f} exists"
  else
    fail "${f} MISSING"
  fi
done

# Validate es_settings.cfg is valid XML
if [ -f "${ES_DIR}/es_settings.cfg.r36splus" ]; then
  # Basic XML check — must have at least one element
  if grep -q "name=" "${ES_DIR}/es_settings.cfg.r36splus"; then
    ok "es_settings.cfg.r36splus has XML content"
  else
    fail "es_settings.cfg.r36splus appears empty or malformed"
  fi
  # Check for 720x720 resolution
  if grep -q "720" "${ES_DIR}/es_settings.cfg.r36splus"; then
    ok "es_settings.cfg.r36splus references 720 (display resolution)"
  else
    info "es_settings.cfg.r36splus does not explicitly mention 720 resolution"
  fi
fi

# Validate es_input.cfg is valid XML with inputConfig
if [ -f "${ES_DIR}/es_input.cfg.r36splus" ]; then
  grep -q "inputConfig" "${ES_DIR}/es_input.cfg.r36splus" && ok "es_input.cfg has inputConfig" || fail "es_input.cfg missing inputConfig"
  grep -q "GO-Super Gamepad" "${ES_DIR}/es_input.cfg.r36splus" && ok "es_input.cfg references GO-Super Gamepad" || fail "es_input.cfg missing device name"

  # Check all required buttons are mapped
  for btn in "name=\"up\"" "name=\"down\"" "name=\"left\"" "name=\"right\"" "name=\"a\"" "name=\"b\"" "name=\"start\"" "name=\"select\""; do
    grep -q "${btn}" "${ES_DIR}/es_input.cfg.r36splus" && ok "es_input.cfg maps ${btn}" || fail "es_input.cfg missing ${btn}"
  done
fi

# Validate es_systems.cfg has m8c entry
if [ -f "${ES_DIR}/es_systems.cfg.r36splus" ]; then
  grep -q "<name>m8c</name>" "${ES_DIR}/es_systems.cfg.r36splus" && \
    ok "es_systems.cfg.r36splus has m8c system entry" || \
    fail "es_systems.cfg.r36splus MISSING m8c system entry"

  grep -q "launch_m8c" "${ES_DIR}/es_systems.cfg.r36splus" && \
    ok "es_systems.cfg m8c entry uses launch_m8c launcher" || \
    fail "es_systems.cfg m8c entry missing launch_m8c"
fi

# ---------------------------------------------------------------------------
# Test 4: Scripts
# ---------------------------------------------------------------------------
echo ""
echo "--- Scripts ---"

SCRIPT_FILES=(
  "scripts/launch_m8c.sh"
  "scripts/m8c_setup.sh"
)

for f in "${SCRIPT_FILES[@]}"; do
  if [ -f "${PROJECT_DIR}/${f}" ]; then
    ok "${f} exists"
    bash -n "${PROJECT_DIR}/${f}" 2>/dev/null && ok "${f} syntax OK" || fail "${f} syntax ERROR"
    [ -x "${PROJECT_DIR}/${f}" ] || chmod +x "${PROJECT_DIR}/${f}"
  else
    fail "${f} MISSING"
  fi
done

# Check launch_m8c.sh has key components
LAUNCH="${PROJECT_DIR}/scripts/launch_m8c.sh"
if [ -f "${LAUNCH}" ]; then
  grep -q "performance" "${LAUNCH}" && ok "launch_m8c.sh sets performance governor" || fail "launch_m8c.sh missing performance governor"
  grep -q "/dev/m8" "${LAUNCH}"     && ok "launch_m8c.sh checks for M8 device"    || fail "launch_m8c.sh missing M8 device check"
  grep -q "m8c_bin\|M8C_BIN" "${LAUNCH}" && ok "launch_m8c.sh references m8c binary" || fail "launch_m8c.sh missing binary path"
fi

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------
echo ""
echo "--- Results: ${PASS} passed, ${FAIL} failed ---"
[ "${FAIL}" -gt 0 ] && exit 1 || exit 0
