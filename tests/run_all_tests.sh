#!/bin/bash
# =============================================================================
# run_all_tests.sh — M8HeadlessDarkOS Test Suite Runner
# =============================================================================
# Runs all validation tests and reports results.
# Exit code: 0 = all passed, 1 = one or more failures
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

PASS=0
FAIL=0
SKIP=0
ERRORS=()

# Color codes (only if terminal supports them)
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

run_test_suite() {
  local suite="$1"
  local name="$2"
  echo ""
  echo -e "${BLUE}--- Running: ${name} ---${NC}"

  if [ ! -f "${suite}" ]; then
    echo -e "  ${YELLOW}SKIP${NC}: ${suite} not found"
    SKIP=$((SKIP+1))
    return
  fi

  bash "${suite}"
  local exit_code=$?

  if [ "${exit_code}" -eq 0 ]; then
    echo -e "  ${GREEN}SUITE PASSED${NC}: ${name}"
    PASS=$((PASS+1))
  else
    echo -e "  ${RED}SUITE FAILED${NC}: ${name} (exit code ${exit_code})"
    FAIL=$((FAIL+1))
    ERRORS+=("${name}")
  fi
}

echo "============================================================"
echo " M8HeadlessDarkOS Test Suite"
echo " Project: ${PROJECT_DIR}"
echo " Date:    $(date)"
echo "============================================================"

cd "${PROJECT_DIR}" || exit 1

run_test_suite "tests/test_build_scripts.sh"  "Build Script Validation"
run_test_suite "tests/test_device_config.sh"  "Device Configuration Validation"
run_test_suite "tests/test_m8c_binary.sh"     "M8C Binary Validation"
run_test_suite "tests/test_emulationstation.sh" "EmulationStation Config Validation"

echo ""
echo "============================================================"
echo " Test Results"
echo "============================================================"
echo -e "  ${GREEN}PASSED${NC}:  ${PASS}"
echo -e "  ${RED}FAILED${NC}:  ${FAIL}"
echo -e "  ${YELLOW}SKIPPED${NC}: ${SKIP}"

if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""
  echo "Failed suites:"
  for err in "${ERRORS[@]}"; do
    echo -e "  ${RED}✗${NC} ${err}"
  done
fi

echo "============================================================"

if [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
exit 0
