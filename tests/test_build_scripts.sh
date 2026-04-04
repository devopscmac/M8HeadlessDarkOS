#!/bin/bash
# =============================================================================
# test_build_scripts.sh — Validate M8HeadlessDarkOS build scripts
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
DARKOS_DIR="${DARKOS_DIR:-${PROJECT_DIR}/../dArkOS}"

PASS=0
FAIL=0

ok()   { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
info() { echo "  INFO: $1"; }

echo "=== Build Script Validation ==="
echo "Project: ${PROJECT_DIR}"
echo "dArkOS:  ${DARKOS_DIR}"
echo ""

# ---------------------------------------------------------------------------
# Test 1: Required files exist
# ---------------------------------------------------------------------------
echo "--- Required files ---"

REQUIRED_FILES=(
  "Makefile"
  "build_r36splus.sh"
  "build_m8c.sh"
  "prepare.sh"
  "finishing_touches_r36splus.sh"
)

for f in "${REQUIRED_FILES[@]}"; do
  if [ -f "${PROJECT_DIR}/${f}" ]; then
    ok "${f} exists"
  else
    fail "${f} MISSING"
  fi
done

# ---------------------------------------------------------------------------
# Test 2: Shell scripts are executable
# ---------------------------------------------------------------------------
echo ""
echo "--- Script permissions ---"

EXEC_FILES=(
  "build_r36splus.sh"
  "build_m8c.sh"
  "prepare.sh"
  "finishing_touches_r36splus.sh"
  "scripts/launch_m8c.sh"
  "scripts/m8c_setup.sh"
)

for f in "${EXEC_FILES[@]}"; do
  # Mark as executable if not already (this is a build system, not a security concern)
  chmod +x "${PROJECT_DIR}/${f}" 2>/dev/null
  if [ -x "${PROJECT_DIR}/${f}" ]; then
    ok "${f} is executable"
  else
    fail "${f} not executable"
  fi
done

# ---------------------------------------------------------------------------
# Test 3: Bash syntax check on all .sh files
# ---------------------------------------------------------------------------
echo ""
echo "--- Shell syntax checks ---"

find "${PROJECT_DIR}" -name "*.sh" -not -path "*/.git/*" | sort | while read -r script; do
  rel="${script#${PROJECT_DIR}/}"
  if bash -n "${script}" 2>/dev/null; then
    ok "syntax OK: ${rel}"
  else
    # Print the actual error
    SYNTAX_ERR=$(bash -n "${script}" 2>&1)
    fail "syntax ERROR in ${rel}: ${SYNTAX_ERR}"
  fi
done

# ---------------------------------------------------------------------------
# Test 4: dArkOS reference paths exist
# ---------------------------------------------------------------------------
echo ""
echo "--- dArkOS dependency paths ---"

if [ -d "${DARKOS_DIR}" ]; then
  ok "dArkOS directory exists at ${DARKOS_DIR}"

  DARKOS_REQUIRED=(
    "utils.sh"
    "prepare.sh"
    "bootstrap_rootfs.sh"
    "build_deps.sh"
    "build_sdl2.sh"
    "build_retroarch.sh"
    "finishing_touches.sh"
    "cleanup_filesystem.sh"
    "write_rootfs.sh"
    "clean_mounts.sh"
    "create_image.sh"
  )

  for f in "${DARKOS_REQUIRED[@]}"; do
    if [ -f "${DARKOS_DIR}/${f}" ]; then
      ok "dArkOS/${f} exists"
    else
      fail "dArkOS/${f} MISSING (required by build_r36splus.sh)"
    fi
  done
else
  fail "dArkOS directory NOT FOUND at ${DARKOS_DIR}"
  info "Set DARKOS_DIR=<path> to fix this"
fi

# ---------------------------------------------------------------------------
# Test 5: m8c source directory
# ---------------------------------------------------------------------------
echo ""
echo "--- m8c source ---"

M8C_REPO="${M8C_REPO:-${PROJECT_DIR}/../m8c}"
if [ -d "${M8C_REPO}" ]; then
  ok "m8c source found at ${M8C_REPO}"
  [ -f "${M8C_REPO}/CMakeLists.txt" ] && ok "CMakeLists.txt present" || fail "CMakeLists.txt MISSING"
  [ -f "${M8C_REPO}/Makefile" ]       && ok "Makefile present"       || fail "Makefile MISSING"
  [ -f "${M8C_REPO}/src/main.c" ]     && ok "src/main.c present"     || fail "src/main.c MISSING"
  [ -f "${M8C_REPO}/gamecontrollerdb.txt" ] && ok "gamecontrollerdb.txt present" || fail "gamecontrollerdb.txt MISSING"
else
  fail "m8c repo NOT FOUND at ${M8C_REPO}"
  info "Set M8C_REPO=<path> to fix this"
fi

# ---------------------------------------------------------------------------
# Test 6: Makefile targets
# ---------------------------------------------------------------------------
echo ""
echo "--- Makefile targets ---"

EXPECTED_TARGETS=("r36splus" "test" "preflight" "clean" "clean_complete" "help")
for target in "${EXPECTED_TARGETS[@]}"; do
  if grep -q "^${target}:" "${PROJECT_DIR}/Makefile"; then
    ok "Makefile target '${target}' exists"
  else
    fail "Makefile target '${target}' MISSING"
  fi
done

# ---------------------------------------------------------------------------
# Test 7: build_r36splus.sh contains required exports
# ---------------------------------------------------------------------------
echo ""
echo "--- build_r36splus.sh configuration ---"

BUILD_SCRIPT="${PROJECT_DIR}/build_r36splus.sh"
REQUIRED_EXPORTS=(
  "CHIPSET=rk3326"
  "UNIT=r36splus"
  "SCREEN_ROTATION"
  "KERNEL_DTB"
  "ROOT_FILESYSTEM_FORMAT"
)

for export_var in "${REQUIRED_EXPORTS[@]}"; do
  if grep -q "${export_var}" "${BUILD_SCRIPT}"; then
    ok "build_r36splus.sh sets ${export_var}"
  else
    fail "build_r36splus.sh missing ${export_var}"
  fi
done

# Check m8c build step is included
if grep -q "build_m8c" "${BUILD_SCRIPT}"; then
  ok "build_r36splus.sh includes m8c build step"
else
  fail "build_r36splus.sh missing m8c build step"
fi

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------
echo ""
echo "--- Results: ${PASS} passed, ${FAIL} failed ---"
[ "${FAIL}" -gt 0 ] && exit 1 || exit 0
