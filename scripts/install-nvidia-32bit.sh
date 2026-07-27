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

NVIDIA_PKG="nvidia"
chip=$(lspci | grep -i nvidia | head -1 | grep -oiP '(GK|GF|GT)[0-9]{3}')
if [[ "$chip" =~ ^GK ]]; then
    NVIDIA_PKG="nvidia470"
elif [[ "$chip" =~ ^GF ]]; then
    NVIDIA_PKG="nvidia390"
fi
log "Detected GPU → ${NVIDIA_PKG}-libs-32bit"

LIBS_32="${NVIDIA_PKG}-libs-32bit"

# Пробуем сначала из обычного репозитория
if xbps-install -Sy "$LIBS_32" 2>/dev/null; then
    log "$LIBS_32 installed from main repo"
else
    log "Main repo failed — trying local build from ~/void-packages..."
    if [[ -n "${SUDO_USER:-}" ]]; then
        REAL_HOME="$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6)"
    else
        REAL_HOME="$HOME"
    fi
    : "${REAL_HOME:=$HOME}"
    REPO_DIR="$REAL_HOME/void-packages"
    if [ -d "$REPO_DIR/hostdir/binpkgs/multilib/nonfree" ]; then
        xbps-install -Sy --repository="$REPO_DIR/hostdir/binpkgs/multilib/nonfree" "$LIBS_32"
    else
        log "Local repo not found. Build first:"
        log "  cd ~/void-packages && ./xbps-src pkg ${LIBS_32}"
        log "  sudo xbps-install -y --repository=/hostdir/binpkgs/multilib/nonfree ${LIBS_32}"
        exit 1
    fi
fi

log "Done."
