#!/bin/bash
# =============================================================================
# test_m8c_binary.sh — Validate precompiled m8c binary for R36S Plus
# =============================================================================
# Tests the m8c binary if it exists in bin/
# Skips gracefully if binary hasn't been compiled yet.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
M8C_REPO="${M8C_REPO:-${PROJECT_DIR}/../m8c}"

PASS=0
FAIL=0
SKIP=0

ok()   { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP+1)); }
info() { echo "  INFO: $1"; }

echo "=== M8C Binary Validation ==="
echo ""

# ---------------------------------------------------------------------------
# Test 1: Check m8c source repo
# ---------------------------------------------------------------------------
echo "--- m8c source repo ---"

if [ -d "${M8C_REPO}" ]; then
  ok "m8c source repo exists at ${M8C_REPO}"

  # Check source files
  [ -f "${M8C_REPO}/CMakeLists.txt" ]   && ok "CMakeLists.txt present" || fail "CMakeLists.txt MISSING"
  [ -f "${M8C_REPO}/src/main.c" ]       && ok "src/main.c present"     || fail "src/main.c MISSING"
  [ -f "${M8C_REPO}/src/render.c" ]     && ok "src/render.c present"   || skip "src/render.c not found (optional)"
  [ -f "${M8C_REPO}/src/config.c" ]     && ok "src/config.c present"   || fail "src/config.c MISSING"
  [ -f "${M8C_REPO}/gamecontrollerdb.txt" ] && ok "gamecontrollerdb.txt present" || fail "gamecontrollerdb.txt MISSING"
  [ -f "${M8C_REPO}/README.md" ]        && ok "README.md present"      || skip "README.md not found"

  # Check for SDL3 (required for m8c 2.x+)
  if grep -q "SDL3\|SDL2" "${M8C_REPO}/CMakeLists.txt" 2>/dev/null; then
    SDL_VER=$(grep -o "SDL[23]" "${M8C_REPO}/CMakeLists.txt" | head -1)
    ok "CMakeLists.txt references ${SDL_VER}"
  else
    fail "CMakeLists.txt missing SDL dependency"
  fi

  # Check for libserialport backend
  if [ -f "${M8C_REPO}/src/backends/m8_libserialport.c" ]; then
    ok "libserialport backend present (recommended for R36S Plus)"
  else
    info "libserialport backend file not found at expected path"
    # Fallback check
    find "${M8C_REPO}" -name "*serialport*" 2>/dev/null | head -3 | while read f; do
      info "Found: ${f}"
    done
  fi
else
  fail "m8c source repo NOT FOUND at ${M8C_REPO}"
  info "Set M8C_REPO=<path> to the m8c repository"
fi

# ---------------------------------------------------------------------------
# Test 2: Check for precompiled binary in bin/
# ---------------------------------------------------------------------------
echo ""
echo "--- Precompiled binary ---"

M8C_BINARY="${PROJECT_DIR}/bin/m8c-r36splus"
M8C_BINARY_ALT="${PROJECT_DIR}/bin/m8c"

if [ -f "${M8C_BINARY}" ]; then
  ok "m8c binary found at bin/m8c-r36splus"

  # Check it's ARM64
  ARCH_INFO=$(file "${M8C_BINARY}" 2>/dev/null)
  echo "  INFO: $(echo "${ARCH_INFO}" | cut -d: -f2-)"

  if echo "${ARCH_INFO}" | grep -qi "aarch64\|ARM aarch64\|64-bit.*ARM"; then
    ok "Binary is ARM64 (aarch64) — correct for R36S Plus"
  elif echo "${ARCH_INFO}" | grep -qi "ARM"; then
    info "Binary is ARM (32-bit) — may work but ARM64 preferred"
  else
    fail "Binary architecture unclear: ${ARCH_INFO}"
  fi

  # Check it's an ELF executable
  if echo "${ARCH_INFO}" | grep -qi "ELF"; then
    ok "Binary is ELF format"
  else
    fail "Binary is NOT ELF format: ${ARCH_INFO}"
  fi

  # Check size (m8c should be at least 100KB)
  M8C_SIZE=$(stat -c%s "${M8C_BINARY}" 2>/dev/null || stat -f%z "${M8C_BINARY}" 2>/dev/null)
  if [ -n "${M8C_SIZE}" ] && [ "${M8C_SIZE}" -gt 102400 ]; then
    ok "Binary size OK: $(( M8C_SIZE / 1024 ))KB"
  elif [ -n "${M8C_SIZE}" ]; then
    fail "Binary suspiciously small: ${M8C_SIZE} bytes (expected >100KB)"
  fi

elif [ -f "${M8C_BINARY_ALT}" ]; then
  ok "m8c binary found at bin/m8c"
  info "Consider renaming to bin/m8c-r36splus for clarity"
else
  skip "No precompiled binary found in bin/ (will be built during OS build)"
  info "Run 'make r36splus' to build the full OS including m8c"
  info "Or manually build m8c for aarch64 and place in bin/m8c-r36splus"
fi

# ---------------------------------------------------------------------------
# Test 3: Verify m8c config for R36S Plus correctness
# ---------------------------------------------------------------------------
echo ""
echo "--- m8c config validation ---"

M8C_CFG="${PROJECT_DIR}/device/r36splus/m8c.ini"
if [ -f "${M8C_CFG}" ]; then
  ok "m8c.ini exists"

  # Check fullscreen is enabled (required for handheld)
  if grep -qE "init_fullscreen\s*=\s*true" "${M8C_CFG}"; then
    ok "init_fullscreen=true (correct for handheld)"
  else
    fail "init_fullscreen not set to true in m8c.ini"
  fi

  # Check audio is enabled
  if grep -qE "audio_enabled\s*=\s*true" "${M8C_CFG}"; then
    ok "audio_enabled=true"
  else
    info "audio_enabled not set to true (user may prefer to enable manually)"
  fi

  # Check D-pad mappings
  for key in "key_up" "key_down" "key_left" "key_right"; do
    if grep -qE "^${key}\s*=" "${M8C_CFG}"; then
      ok "${key} is mapped"
    else
      fail "${key} not mapped in m8c.ini"
    fi
  done

  # Check M8 function keys
  for key in "key_opt" "key_edit"; do
    if grep -qE "^${key}\s*=" "${M8C_CFG}"; then
      ok "M8 ${key} is mapped"
    else
      fail "M8 ${key} not mapped in m8c.ini"
    fi
  done
else
  fail "m8c.ini not found at ${M8C_CFG}"
fi

# ---------------------------------------------------------------------------
# Test 4: Check build_m8c.sh correctness
# ---------------------------------------------------------------------------
echo ""
echo "--- build_m8c.sh validation ---"

BUILD_M8C="${PROJECT_DIR}/build_m8c.sh"
if [ -f "${BUILD_M8C}" ]; then
  ok "build_m8c.sh exists"
  bash -n "${BUILD_M8C}" 2>/dev/null && ok "build_m8c.sh syntax OK" || fail "build_m8c.sh syntax ERROR"

  # Check for required build steps
  grep -q "cmake" "${BUILD_M8C}"                  && ok "uses cmake build system"       || fail "cmake not referenced"
  grep -q "USE_LIBSERIALPORT" "${BUILD_M8C}"       && ok "enables libserialport backend" || fail "libserialport backend not set"
  grep -q "install_package" "${BUILD_M8C}"         && ok "installs dependencies"         || fail "dependency installation missing"
  grep -q "udev\|99-m8-headless" "${BUILD_M8C}"   && ok "installs udev rules"           || fail "udev rules not installed"
  grep -q "dialout" "${BUILD_M8C}"                 && ok "adds user to dialout group"    || fail "dialout group setup missing"
  grep -q "verify_action" "${BUILD_M8C}"           && ok "uses verify_action error check" || fail "verify_action error checking missing"
  grep -q "cache\|CACHE" "${BUILD_M8C}"            && ok "implements build caching"      || fail "build caching not implemented"
fi

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------
echo ""
echo "--- Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped ---"
[ "${FAIL}" -gt 0 ] && exit 1 || exit 0
