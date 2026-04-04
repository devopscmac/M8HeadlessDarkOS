#!/bin/bash
# =============================================================================
# test_emulationstation.sh — Validate EmulationStation configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
ES_DIR="${PROJECT_DIR}/Emulationstation"

PASS=0
FAIL=0

ok()   { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
info() { echo "  INFO: $1"; }

echo "=== EmulationStation Configuration Validation ==="
echo ""

# ---------------------------------------------------------------------------
# Test 1: All ES files for r36splus exist
# ---------------------------------------------------------------------------
echo "--- Required ES files ---"

ES_FILES=(
  "es_settings.cfg.r36splus"
  "es_input.cfg.r36splus"
  "es_systems.cfg.r36splus"
  "emulationstation.sh.r36splus"
)

for f in "${ES_FILES[@]}"; do
  [ -f "${ES_DIR}/${f}" ] && ok "${f}" || fail "${f} MISSING"
done

# ---------------------------------------------------------------------------
# Test 2: es_settings.cfg correctness
# ---------------------------------------------------------------------------
echo ""
echo "--- es_settings.cfg.r36splus ---"

SETTINGS="${ES_DIR}/es_settings.cfg.r36splus"
if [ -f "${SETTINGS}" ]; then
  # Must have ThemeSet
  grep -q "ThemeSet" "${SETTINGS}"       && ok "ThemeSet present"       || fail "ThemeSet MISSING"
  # Must have TransitionStyle
  grep -q "TransitionStyle" "${SETTINGS}" && ok "TransitionStyle present" || fail "TransitionStyle MISSING"
  # Must reference 720 for square screen
  grep -q "720" "${SETTINGS}"            && ok "720 display size referenced" || info "720 not explicitly in es_settings (may be OK)"
  # Must have 1:1 or square aspect setting
  grep -q "1:1\|square\|720" "${SETTINGS}" && ok "Square screen aspect configured" || info "No explicit 1:1 aspect setting found"
fi

# ---------------------------------------------------------------------------
# Test 3: es_input.cfg completeness
# ---------------------------------------------------------------------------
echo ""
echo "--- es_input.cfg.r36splus ---"

INPUT="${ES_DIR}/es_input.cfg.r36splus"
if [ -f "${INPUT}" ]; then
  # Verify XML structure
  grep -q "<?xml" "${INPUT}" && ok "Has XML declaration" || fail "Missing XML declaration"
  grep -q "<inputList>" "${INPUT}" && ok "Has <inputList>" || fail "Missing <inputList>"
  grep -q "<inputConfig" "${INPUT}" && ok "Has <inputConfig>" || fail "Missing <inputConfig>"
  grep -q "</inputList>" "${INPUT}" && ok "Properly closed </inputList>" || fail "Missing </inputList>"

  # All 8 required directional + action buttons
  REQUIRED_BUTTONS=("up" "down" "left" "right" "a" "b" "start" "select")
  for btn in "${REQUIRED_BUTTONS[@]}"; do
    grep -q "name=\"${btn}\"" "${INPUT}" && ok "Button '${btn}' mapped" || fail "Button '${btn}' NOT mapped"
  done

  # Optional but recommended
  OPTIONAL_BUTTONS=("x" "y" "leftshoulder" "rightshoulder" "leftanalogup" "rightanalogup")
  for btn in "${OPTIONAL_BUTTONS[@]}"; do
    grep -q "name=\"${btn}\"" "${INPUT}" && ok "Button '${btn}' mapped (optional)" || info "Button '${btn}' not mapped (optional)"
  done
fi

# ---------------------------------------------------------------------------
# Test 4: es_systems.cfg.r36splus has m8c + core systems
# ---------------------------------------------------------------------------
echo ""
echo "--- es_systems.cfg.r36splus ---"

SYSTEMS="${ES_DIR}/es_systems.cfg.r36splus"
if [ -f "${SYSTEMS}" ]; then
  # XML structure
  grep -q "<systemList" "${SYSTEMS}" && ok "Has <systemList>" || fail "Missing <systemList>"
  grep -q "</systemList>" "${SYSTEMS}" && ok "Closed </systemList>" || fail "Missing </systemList>"

  # M8C entry — required for this distribution
  grep -q "<name>m8c</name>" "${SYSTEMS}"           && ok "M8C system entry present"        || fail "M8C system entry MISSING"
  grep -q "launch_m8c\|m8c" "${SYSTEMS}"            && ok "M8C has launch command"          || fail "M8C launch command MISSING"
  grep -q "Dirtywave\|M8 Music" "${SYSTEMS}"        && ok "M8C has manufacturer/fullname"   || info "M8C manufacturer info not found"

  # Core gaming systems
  CORE_SYSTEMS=("nes" "snes" "gb" "gba" "genesis" "psx" "n64")
  for sys in "${CORE_SYSTEMS[@]}"; do
    grep -q "<name>${sys}</name>" "${SYSTEMS}" && ok "System '${sys}' present" || info "System '${sys}' not found (may be in full config)"
  done

  # Each system must have <command>
  SYSTEM_COUNT=$(grep -c "<name>" "${SYSTEMS}" 2>/dev/null)
  COMMAND_COUNT=$(grep -c "<command>" "${SYSTEMS}" 2>/dev/null)
  if [ "${SYSTEM_COUNT}" -eq "${COMMAND_COUNT}" ]; then
    ok "All ${SYSTEM_COUNT} systems have launch commands"
  else
    fail "System count (${SYSTEM_COUNT}) != command count (${COMMAND_COUNT})"
  fi
fi

# ---------------------------------------------------------------------------
# Test 5: emulationstation.sh.r36splus
# ---------------------------------------------------------------------------
echo ""
echo "--- emulationstation.sh.r36splus ---"

ES_SH="${ES_DIR}/emulationstation.sh.r36splus"
if [ -f "${ES_SH}" ]; then
  # Syntax check
  bash -n "${ES_SH}" 2>/dev/null && ok "Shell syntax OK" || fail "Shell syntax ERROR"

  # Must reference M8 headless in BaRT menu
  grep -qi "m8\|headless" "${ES_SH}" && ok "BaRT menu has M8 option" || fail "BaRT menu missing M8 option"

  # Must handle performance mode for RetroArch
  grep -q "performance" "${ES_SH}" && ok "Sets performance governor" || fail "Missing performance governor"

  # Must have GPU address for RK3326
  grep -q "ff400000" "${ES_SH}" && ok "RK3326 GPU address ff400000 referenced" || fail "RK3326 GPU address missing"

  # Must source buttonmon.sh
  grep -q "buttonmon.sh" "${ES_SH}" && ok "Sources buttonmon.sh" || fail "buttonmon.sh not sourced"
fi

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------
echo ""
echo "--- Results: ${PASS} passed, ${FAIL} failed ---"
[ "${FAIL}" -gt 0 ] && exit 1 || exit 0
