#!/usr/bin/env bash
# install-nvidia-32bit.sh — Install 32-bit NVIDIA libraries for Wine/Proton
set -euo pipefail

LOG="/tmp/void-tool-nvidia32.log"
log() { echo "[nvidia-32bit] $*" | tee -a "$LOG"; }

check_installed() {
    if xbps-query nvidia-libs-32bit >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

if [ "${1:-}" = "--check" ]; then
    if check_installed; then
        echo "nvidia-32bit: installed"
        exit 0
    fi
    echo "nvidia-32bit: not installed"
    exit 1
fi

if [ "${1:-}" != "--install" ]; then
    echo "Usage: $0 [--check|--install]"
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo "Запусти от root: sudo $0 --install"
    exit 1
fi

log "=== void-tool nvidia-libs-32bit installer ==="

# Пробуем сначала из обычного репозитория
if xbps-install -Sy nvidia-libs-32bit 2>/dev/null; then
    log "nvidia-libs-32bit installed from main repo"
else
    log "Main repo failed — trying local build from ~/void-packages..."
    REPO_DIR="/home/ig_ro/void-packages"
    if [ -d "$REPO_DIR/hostdir/binpkgs/multilib/nonfree" ]; then
        xbps-install -Sy --repository="$REPO_DIR/hostdir/binpkgs/multilib/nonfree" nvidia-libs-32bit
    else
        log "Local repo not found. Build first:"
        log "  cd ~/void-packages && ./xbps-src pkg nvidia-libs-32bit"
        log "  sudo xbps-install -y --repository=/hostdir/binpkgs/multilib/nonfree nvidia-libs-32bit"
        exit 1
    fi
fi

log "Done."
