#!/usr/bin/env bash
# install-fastfetch-img.sh — fastfetch with chafa image support
set -euo pipefail

LOG="/tmp/void-tool-fastfetch.log"
log() { echo "[fastfetch] $*" | tee -a "$LOG"; }

BUILD_DIR="/tmp/fastfetch-build"

check_installed() {
    if command -v fastfetch &>/dev/null && fastfetch --list-features 2>/dev/null | grep -q chafa; then
        return 0
    fi
    return 1
}

if [ "${1:-}" = "--check" ]; then
    if check_installed; then
        ver=$(fastfetch --version 2>/dev/null | head -1)
        echo "fastfetch: installed ($ver) with chafa"
        exit 0
    fi
    if command -v fastfetch &>/dev/null; then
        echo "fastfetch: installed but without chafa (images disabled)"
    else
        echo "fastfetch: not installed"
    fi
    exit 1
fi

if [ "${1:-}" != "--install" ]; then
    echo "Usage: $0 [--check|--install]"
    exit 1
fi

log "=== void-tool fastfetch (image support) installer ==="

# 1. Install build deps
DEPS=(cmake make gcc pkg-config git chafa-devel libmagick-devel glibc-devel)
log "Installing deps: ${DEPS[*]}"
sudo xbps-install -Sy "${DEPS[@]}"

# 2. Clone / update source
if [[ -d "$BUILD_DIR/fastfetch" ]]; then
    log "Updating fastfetch source..."
    git -C "$BUILD_DIR/fastfetch" pull --ff-only || true
else
    log "Cloning fastfetch..."
    mkdir -p "$BUILD_DIR"
    git clone https://github.com/fastfetch-cli/fastfetch.git "$BUILD_DIR/fastfetch"
fi

# 3. Build
log "Building fastfetch with imagemagick7 + chafa..."
cd "$BUILD_DIR/fastfetch"
rm -rf build
cmake -B build \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_IMAGEMAGICK7=ON
cmake --build build -j"$(nproc)"

# 4. Install
log "Installing..."
sudo cmake --install build

# 5. Verify
if check_installed; then
    log "Done. fastfetch with chafa installed."
else
    log "ERROR: build succeeded but chafa check failed"
    exit 1
fi

# 6. Cleanup build dir
rm -rf "$BUILD_DIR"

log "Done."
