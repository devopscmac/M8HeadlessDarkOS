# Local Repository Mirrors

This directory contains local git mirrors of external repositories required
by the M8HeadlessDarkOS build process. Use local mirrors when:

- The upstream GitHub repositories are unavailable
- You need to make customizations to the source
- You want a fully offline/air-gapped build

## Setting Up Local Mirrors

Run the following to create local mirrors of all critical dependencies:

```bash
cd local_repos/
bash setup_mirrors.sh
```

## Repository Inventory

### Critical Build Dependencies

| Repository | Purpose | Upstream URL |
|-----------|---------|-------------|
| `rk3326_core_builds` | Prebuilt emulator binaries + Mali GPU drivers for RK3326 | `christianhaitian/rk3326_core_builds` |
| `retroarch-cores` | Prebuilt libretro cores | `christianhaitian/retroarch-cores` |
| `linux` | Custom Linux kernel (RK3326 branch) | `christianhaitian/linux` |
| `gcc-linaro` | ARM64 cross-compiler toolchain | `christianhaitian/gcc-linaro-...` |
| `EmulationStation-fcamod` | EmulationStation fork | `christianhaitian/EmulationStation-fcamod` |

### m8c Dependencies

| Repository | Purpose | Upstream URL |
|-----------|---------|-------------|
| `m8c` | M8 Headless client source | `laamaa/m8c` |

### Optional Dependencies

| Repository | Purpose | Upstream URL |
|-----------|---------|-------------|
| `gptokeyb` | Gamepad-to-keyboard mapper | `christianhaitian/gptokeyb` |
| `glsl-shaders` | RetroArch video shaders | `libretro/glsl-shaders` |
| `libretro-core-info` | Core metadata | `libretro/libretro-core-info` |
| `retroarch-assets` | RetroArch UI assets | `libretro/retroarch-assets` |
| `PortMaster-GUI` | Game ports framework | `PortsMaster/PortMaster-GUI` |

## Using Local Mirrors During Build

To use local mirrors instead of GitHub, set these environment variables before
running `make r36splus`:

```bash
export RK3326_CORE_BUILDS_REPO="file:///path/to/M8HeadlessDarkOS/local_repos/rk3326_core_builds"
export RETROARCH_CORES_REPO="file:///path/to/M8HeadlessDarkOS/local_repos/retroarch-cores"
export LINUX_KERNEL_REPO="file:///path/to/M8HeadlessDarkOS/local_repos/linux"
```

The build system checks these variables and falls back to the upstream URLs if
the local mirrors don't exist.

## Creating a Full Offline Mirror

```bash
# 1. Create mirrors for all critical repos
mkdir -p local_repos

# Core builds (large — ~2GB)
git clone --mirror https://github.com/christianhaitian/rk3326_core_builds.git \
  local_repos/rk3326_core_builds.git

# Kernel (large — can limit depth)
git clone --mirror --depth=1 \
  -b rg351 https://github.com/christianhaitian/linux.git \
  local_repos/linux.git

# EmulationStation
git clone --mirror https://github.com/christianhaitian/EmulationStation-fcamod.git \
  local_repos/EmulationStation-fcamod.git

# 2. To update mirrors later:
for repo in local_repos/*.git; do
  cd "$repo" && git remote update && cd ..
done
```

## Notes

- Mirror repos use bare format (`.git` suffix) for space efficiency
- The `rk3326_core_builds` repo is the largest (~2GB), containing prebuilt binaries
- The Linux kernel repo is very large; use `--depth=1` for a shallow clone
- The m8c source is already available locally at `../../m8c/`
