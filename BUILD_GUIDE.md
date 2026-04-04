# M8HeadlessDarkOS Build Guide

## Prerequisites

### Host System Requirements

- **OS**: Ubuntu 20.04+ or Debian Bullseye+ (64-bit x86_64)
- **RAM**: 8GB minimum, 16GB recommended
- **Disk**: 50GB free space (build generates ~25GB of intermediate files)
- **CPU**: Any modern x86_64; more cores = faster compilation
- **Internet**: Required for first build (packages, source code)

### Required Directory Layout

The build expects the following sibling directories:

```
Repos/headless/
├── dArkOS/          ← DarkOS build system (https://github.com/christianhaitian/arkos)
├── m8c/             ← m8c source (https://github.com/laamaa/m8c)
└── M8HeadlessDarkOS/  ← This repository
```

To set up:
```bash
mkdir -p ~/Repos/headless
cd ~/Repos/headless

# Clone dArkOS
git clone https://github.com/christianhaitian/arkos.git dArkOS

# Clone m8c
git clone https://github.com/laamaa/m8c.git m8c

# Clone M8HeadlessDarkOS (or it's already here)
git clone <this-repo-url> M8HeadlessDarkOS
```

### Custom Paths

If you have dArkOS or m8c in different locations, set these variables:

```bash
export DARKOS_DIR=/path/to/dArkOS
export M8C_REPO=/path/to/m8c
make r36splus
```

---

## Step-by-Step Build

### Step 1: Verify the build environment

```bash
cd ~/Repos/headless/M8HeadlessDarkOS
make preflight
```

This checks that dArkOS and m8c repos are present and properly structured.
It does NOT install anything or start the build.

### Step 2: (Optional) Enable build caching

Build caching dramatically reduces rebuild times (19h → 3h):

```bash
# Install apt-cacher-ng on the host
sudo apt-get install apt-cacher-ng
sudo systemctl enable --now apt-cacher-ng

# Build with caching enabled (default)
ENABLE_CACHE=y make r36splus
```

### Step 3: Build the OS image

```bash
# Standard build (all options default)
make r36splus

# Build with specific options
ENABLE_CACHE=y BUILD_ARMHF=y BUILD_BLUEALSA=y make r36splus
```

The build will:
1. Install all required host tools (via apt-get, requires sudo)
2. Download and set up the Linaro ARM64 cross-compiler
3. Bootstrap a Debian Trixie ARM64 chroot
4. Build the Linux kernel and all emulators
5. Compile m8c inside the chroot
6. Produce: `M8HeadlessDarkOS_r36splus_<MMDDYYYY>.img.7z`

### Step 4: Flash to SD card

```bash
# Extract the image
7z e M8HeadlessDarkOS_r36splus_*.img.7z

# Find your SD card (CAREFULLY check this is the right device)
lsblk

# Flash (replace /dev/sdX with your SD card)
sudo dd if=M8HeadlessDarkOS_r36splus_*.img of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

---

## Build Options Reference

| Variable | Default | Description |
|---------|---------|-------------|
| `DEBIAN_CODE_NAME` | `trixie` | Debian release. `trixie` = Debian 13 (current testing) |
| `ENABLE_CACHE` | `y` | Use apt-cacher-ng for package caching |
| `BUILD_ARMHF` | `y` | Include 32-bit ARM userspace (required by some emulators) |
| `BUILD_KODI` | `n` | Include Kodi media center (RK3566 only, skip for R36S Plus) |
| `BUILD_BLUEALSA` | `y` | Include Bluetooth audio (bluealsa) support |
| `DARKOS_DIR` | `../dArkOS` | Path to dArkOS repository |
| `M8C_REPO` | `../m8c` | Path to m8c source repository |

---

## Build Stages in Detail

### Kernel Build

The R36S Plus requires a device tree blob (DTB) that matches its hardware:

```
DTB: rk3326-r36splus-linux.dtb
Kernel tree: christianhaitian/linux, branch: rg351
```

The DTB defines the R36S Plus's display panel, GPIO buttons, audio codec (RK817),
and other hardware. If the exact DTB is not present in the kernel tree, the build
will fall back to the closest match (`rk3326-rg351mp-linux.dtb`).

To add a proper R36S Plus DTB:
```bash
# In the kernel source:
cp arch/arm64/boot/dts/rockchip/rk3326-rg351mp-linux.dts \
   arch/arm64/boot/dts/rockchip/rk3326-r36splus-linux.dts
# Edit the display panel section for 720x720 (ST7703 or NV3051D panel)
# Add to Makefile: dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3326-r36splus-linux.dtb
```

### m8c Build

m8c is compiled inside the ARM64 chroot to ensure it links against the correct
runtime libraries:

```
SDL3:          installed from Debian Trixie ARM64 packages
libserialport: installed from Debian Trixie ARM64 packages
Build system:  cmake
Backend:       libserialport (USE_LIBSERIALPORT=ON)
Install path:  /opt/m8c/bin/m8c
```

The build is cached in `Arkbuild_package_cache/rk3326/m8c_<version>.tar.gz`.

---

## Rebuilding After Changes

### Rebuild only m8c

```bash
# Remove m8c cache to force rebuild
rm -f Arkbuild_package_cache/rk3326/m8c_*.tar.gz

# Then re-run the full build (dArkOS caching means only m8c rebuilds)
make r36splus
```

### Rebuild from a specific stage

The build is not easily resumable mid-way (it runs as a single pipeline).
However, with caching enabled, most stages complete from cache in ~3 hours.

To iterate on just the finishing touches:
```bash
# If Arkbuild/ is still mounted and intact:
source utils.sh  # (from dArkOS dir)
CHIPSET=rk3326 UNIT=r36splus source finishing_touches_r36splus.sh
```

### Update m8c to a newer version

```bash
cd ../m8c
git pull
cd ../M8HeadlessDarkOS
rm -f Arkbuild_package_cache/rk3326/m8c_*.tar.gz
make r36splus
```

---

## Cross-Compiling m8c Standalone (Without Full OS Build)

The easiest way is `setup_host.sh`, which handles everything automatically:

```bash
bash setup_host.sh
```

SDL3 is not reliably available as an arm64 package on Ubuntu, so `setup_host.sh`
builds both SDL3 and libserialport from source and installs them to
`/opt/aarch64-sysroot/`. The m8c cmake invocation then uses that sysroot via
`CMAKE_PREFIX_PATH` and `PKG_CONFIG_PATH`.

To do it manually:

```bash
# 1. Install cross-compiler
sudo apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu cmake ninja-build git

SYSROOT=/opt/aarch64-sysroot

# 2. Build SDL3 for aarch64
git clone --depth=1 --branch release-3.2.14 https://github.com/libsdl-org/SDL.git /tmp/SDL3
cmake -S /tmp/SDL3 -B /tmp/SDL3_build -G Ninja \
  -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
  -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
  -DCMAKE_INSTALL_PREFIX=${SYSROOT} \
  -DSDL_SHARED=ON -DSDL_KMSDRM=ON -DSDL_X11=OFF -DSDL_WAYLAND=OFF -DSDL_TESTS=OFF \
  -DSDL_UNIX_CONSOLE_BUILD=ON
cmake --build /tmp/SDL3_build --parallel $(nproc)
sudo cmake --install /tmp/SDL3_build

# 3. Build libserialport for aarch64
git clone --depth=1 https://github.com/sigrokproject/libserialport.git /tmp/libserialport
cd /tmp/libserialport && ./autogen.sh
CC=aarch64-linux-gnu-gcc ./configure --host=aarch64-linux-gnu --prefix=${SYSROOT}
make -j$(nproc) && sudo make install
cd -

# 4. Build m8c
cd ../m8c
PKG_CONFIG_PATH=${SYSROOT}/lib/pkgconfig \
cmake -S . -B build_aarch64 \
  -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
  -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
  -DCMAKE_PREFIX_PATH=${SYSROOT} \
  -DCMAKE_FIND_ROOT_PATH=${SYSROOT} \
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_EXE_LINKER_FLAGS="-L${SYSROOT}/lib -Wl,-rpath-link,${SYSROOT}/lib" \
  -DUSE_LIBSERIALPORT=ON -DUSE_LIBUSB=OFF -DUSE_RTMIDI=OFF
cmake --build build_aarch64 --parallel $(nproc)
cp build_aarch64/m8c ../M8HeadlessDarkOS/bin/m8c-r36splus
```

---

## Troubleshooting

### Build fails: "debootstrap: not found"

```bash
sudo apt-get install debootstrap
```

### Build fails: "qemu-aarch64-static: not found"

```bash
sudo apt-get install qemu-user-static
```

### Build fails: "dArkOS not found"

Make sure dArkOS is at `../dArkOS` relative to M8HeadlessDarkOS, or set:
```bash
DARKOS_DIR=/path/to/dArkOS make r36splus
```

### Build hangs on kernel compilation

This is normal — kernel compilation for ARM64 can take 30–90 minutes on first
build. With the Linaro toolchain and ccache, subsequent builds are faster.

### "Arkbuild already mounted" error

```bash
source ../dArkOS/utils.sh && remove_arkbuild
```

### m8c fails to launch: "No M8 device found"

```bash
# Check USB connection
lsusb | grep -i "16c0\|Teensy\|M8"

# Check serial device
ls -la /dev/ttyACM*

# Check group membership
groups ark
```

### SD card won't boot

1. Verify the image was written completely: re-flash with `dd`
2. Check the partition table: `fdisk -l /dev/sdX`
3. Verify U-Boot wrote correctly: check sector 64 is not zero:
   `sudo dd if=/dev/sdX bs=512 skip=64 count=1 | hexdump -C | head`

---

## Build Time Estimates

| Scenario | Approximate Time |
|---------|-----------------|
| First build, no cache | 15–19 hours |
| Subsequent build, cache enabled | 2–4 hours |
| Rebuild after m8c change only | ~30 minutes |
| Cross-compile m8c only (no OS) | ~5–10 minutes |

Times based on 8-core x86_64 system @ 3.5 GHz, 16GB RAM, SSD.
