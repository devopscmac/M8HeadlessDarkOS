SHELL := /bin/bash

# M8HeadlessDarkOS - DarkOS with M8 Headless Integration
# Target: R36S Plus (RK3326/PK3326 SoC, 720x720 display)
# Based on: dArkOS (https://github.com/christianhaitian/arkos)

DEBIAN_CODE_NAME ?= trixie
ENABLE_CACHE     ?= y
BUILD_KODI       ?= n
BUILD_ARMHF      ?= y
BUILD_BLUEALSA   ?= y
DARKOS_DIR       ?= ../dArkOS
M8C_REPO         ?= ../m8c

export DEBIAN_CODE_NAME
export ENABLE_CACHE
export BUILD_KODI
export BUILD_ARMHF
export BUILD_BLUEALSA
export DARKOS_DIR
export M8C_REPO

ifeq ($(DEBIAN_CODE_NAME),)
  $(error DEBIAN_CODE_NAME is not set. Run with DEBIAN_CODE_NAME=trixie)
endif

.PHONY: all r36splus clean clean_complete test help preflight

all:
	@echo "M8HeadlessDarkOS Build System"
	@echo "=============================="
	@echo ""
	@echo "Usage:  make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  r36splus     Build M8HeadlessDarkOS for R36S Plus (PK3326/RK3326)"
	@echo "  test         Run all validation tests"
	@echo "  preflight    Check build environment without building"
	@echo "  clean        Remove build artifacts"
	@echo "  clean_complete  Remove build artifacts AND caches"
	@echo "  help         Show this help"
	@echo ""
	@echo "Options (env vars):"
	@echo "  DEBIAN_CODE_NAME=$(DEBIAN_CODE_NAME)"
	@echo "  ENABLE_CACHE=$(ENABLE_CACHE)"
	@echo "  BUILD_ARMHF=$(BUILD_ARMHF)"
	@echo "  BUILD_BLUEALSA=$(BUILD_BLUEALSA)"
	@echo "  DARKOS_DIR=$(DARKOS_DIR)"
	@echo "  M8C_REPO=$(M8C_REPO)"

r36splus: preflight
	$(info )
	$(info ============================================================)
	$(info  M8HeadlessDarkOS — R36S Plus (RK3326))
	$(info  Debian: $(DEBIAN_CODE_NAME))
	$(info  Cache:  $(ENABLE_CACHE))
	$(info  ARMHF:  $(BUILD_ARMHF))
	$(info  BT:     $(BUILD_BLUEALSA))
	$(info ============================================================)
	$(info )
	@sleep 3
	./build_r36splus.sh

preflight:
	@echo "Checking build environment..."
	@test -d "$(DARKOS_DIR)" || (echo "ERROR: dArkOS not found at $(DARKOS_DIR). Set DARKOS_DIR=<path>"; exit 1)
	@test -d "$(M8C_REPO)" || (echo "ERROR: m8c not found at $(M8C_REPO). Set M8C_REPO=<path>"; exit 1)
	@test -f "$(DARKOS_DIR)/utils.sh" || (echo "ERROR: $(DARKOS_DIR)/utils.sh not found"; exit 1)
	@test -f "$(DARKOS_DIR)/bootstrap_rootfs.sh" || (echo "ERROR: dArkOS bootstrap not found"; exit 1)
	@test -f "$(M8C_REPO)/Makefile" || (echo "ERROR: m8c Makefile not found at $(M8C_REPO)/Makefile"; exit 1)
	@echo "Preflight OK: dArkOS at $(DARKOS_DIR), m8c at $(M8C_REPO)"

test:
	@echo "Running M8HeadlessDarkOS test suite..."
	@bash tests/run_all_tests.sh

clean:
	[ -d "mnt/boot" ] && sudo umount mnt/boot && sudo rm -rf mnt/boot || true
	[ -d "mnt/roms" ] && sudo umount mnt/roms && sudo rm -rf mnt/roms || true
	[ -d "Arkbuild" ] && source $(DARKOS_DIR)/utils.sh && remove_arkbuild || true
	sudo rm -rf Arkbuild Arkbuild32 Arkbuild-final mnt wget-*
	@echo "Clean complete."

clean_complete: clean
	[ -d "Arkbuild_ccache" ] && sudo umount Arkbuild_ccache || true
	sudo rm -rf Arkbuild_ccache Arkbuild_package_cache
	sudo rm -f build.log*
	@echo "Full clean complete (caches removed)."

help: all
