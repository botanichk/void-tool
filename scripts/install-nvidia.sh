#!/usr/bin/env bash
# install-nvidia.sh — Void Linux GPU driver installer (ex vchwd)
set -euo pipefail

LOG="/tmp/void-tool-nvidia.log"
log() { echo "[nvidia] $*" | tee -a "$LOG"; }

check_installed() {
    if xbps-query nvidia >/dev/null 2>&1 && nvidia-smi &>/dev/null; then
        return 0
    fi
    return 1
}

if [ "${1:-}" = "--check" ]; then
    if check_installed; then
        echo "nvidia: installed ($(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null || echo "?"))"
        exit 0
    fi
    echo "nvidia: not installed"
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

log "=== void-tool NVIDIA installer ==="

CPU_VENDOR="$(awk -F: '/vendor_id/ {print tolower($2)}' /proc/cpuinfo | head -n1 | sed 's/^[ \t]*//')"
case "$CPU_VENDOR" in
  *intel*)  CPU_UCODE="intel-ucode" ;;
  *amd*)    CPU_UCODE="amd-ucode" ;;
  *)        CPU_UCODE="" ;;
esac
log "CPU: $CPU_VENDOR → ${CPU_UCODE:-none}"

KERNEL_PKG="$(xbps-query -l | awk '{print $2}' | grep -E '^linux(-lts|-rt)?-[0-9]' | head -n1)"
case "$KERNEL_PKG" in
  *linux-lts*) PKG_HEADERS="linux-lts-headers" ;;
  *linux-rt*)  PKG_HEADERS="linux-rt-headers" ;;
  *)           PKG_HEADERS="linux-headers" ;;
esac
log "Kernel: $KERNEL_PKG → headers: $PKG_HEADERS"

GPU_INFO="$(lspci | grep -Ei 'vga|3d|display' || true)"
log "GPU: $GPU_INFO"

HAS_INTEL=0; HAS_NVIDIA=0; HAS_AMD=0
echo "$GPU_INFO" | grep -qi "intel"  && HAS_INTEL=1
echo "$GPU_INFO" | grep -qi "nvidia" && HAS_NVIDIA=1
echo "$GPU_INFO" | grep -qi "amd"    && HAS_AMD=1

HAS_HYBRID=0
if [[ "$HAS_INTEL" -eq 1 && "$HAS_NVIDIA" -eq 1 ]]; then
    HAS_HYBRID=1
    log "Detected Intel+NVIDIA hybrid (PRIME)"
elif [[ "$HAS_NVIDIA" -eq 1 ]]; then
    log "Detected NVIDIA-only"
elif [[ "$HAS_AMD" -eq 1 ]]; then
    log "Detected AMD"
elif [[ "$HAS_INTEL" -eq 1 ]]; then
    log "Detected Intel-only"
fi

PKGS=("linux-firmware" "$PKG_HEADERS")
[[ -n "$CPU_UCODE" ]] && PKGS+=("$CPU_UCODE")

if [[ "$HAS_NVIDIA" -eq 1 ]]; then
    PKGS+=("nvidia" "nvidia-libs" "nvidia-libs-32bit" "nvidia-dkms")
    if [[ "$HAS_HYBRID" -eq 0 ]]; then
        PKGS+=("xf86-video-nouveau" "mesa-dri")
    fi
elif [[ "$HAS_AMD" -eq 1 ]]; then
    PKGS+=("mesa-dri" "xf86-video-amdgpu" "mesa-vaapi")
elif [[ "$HAS_INTEL" -eq 1 ]]; then
    PKGS+=("mesa-dri" "xf86-video-intel" "intel-media-driver")
fi

log "Installing: ${PKGS[*]}"
xbps-install -Sy "${PKGS[@]}"

# ── Xorg config ─────────────────────────────────────────
XORG_DIR="/etc/X11/xorg.conf.d"
mkdir -p "$XORG_DIR"

if [[ "$HAS_NVIDIA" -eq 1 ]]; then
    if [[ "$HAS_HYBRID" -eq 1 ]]; then
        log "Configuring Hybrid PRIME..."
        NVIDIA_BUSID=$(lspci | grep -i nvidia | head -n1 | awk '{print $1}' | sed 's/[:.]/ /g')
        BUS=$(printf "%d" "0x$(echo "$NVIDIA_BUSID" | awk '{print $1}')")
        DEV=$(printf "%d" "0x$(echo "$NVIDIA_BUSID" | awk '{print $2}')")
        FUNC=$(printf "%d" "0x$(echo "$NVIDIA_BUSID" | awk '{print $3}')")
        NVIDIA_BUSID="PCI:${BUS}:${DEV}:${FUNC}"
        log "NVIDIA BusID: $NVIDIA_BUSID"
        cat > "$XORG_DIR/10-nvidia-prime.conf" << XEOF
Section "ServerLayout"
    Identifier     "layout"
    Screen         "nvidia"
    Inactive       "intel"
EndSection

Section "Device"
    Identifier     "nvidia"
    Driver         "nvidia"
    BusID          "$NVIDIA_BUSID"
    Option         "AllowEmptyInitialConfiguration"
EndSection

Section "Device"
    Identifier     "intel"
    Driver         "modesetting"
EndSection
XEOF
        log "Creating prime-run helper..."
        cat > /usr/local/bin/prime-run << 'PRIME'
#!/usr/bin/env bash
__NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only __GLX_VENDOR_LIBRARY_NAME=nvidia exec "$@"
PRIME
        chmod +x /usr/local/bin/prime-run
    else
        log "Configuring NVIDIA-only..."
        cat > "$XORG_DIR/10-nvidia.conf" << 'XEOF'
Section "Device"
    Identifier     "nvidia"
    Driver         "nvidia"
    Option         "AllowEmptyInitialConfiguration"
EndSection
XEOF
    fi
elif [[ "$HAS_AMD" -eq 1 ]]; then
    log "Configuring AMD..."
    cat > "$XORG_DIR/10-amdgpu.conf" << 'XEOF'
Section "Device"
    Identifier     "amd"
    Driver         "amdgpu"
EndSection
XEOF
elif [[ "$HAS_INTEL" -eq 1 ]]; then
    log "Configuring Intel..."
    cat > "$XORG_DIR/10-intel.conf" << 'XEOF'
Section "Device"
    Identifier     "intel"
    Driver         "intel"
    Option         "TearFree" "true"
EndSection
XEOF
fi

log "Rebuilding initramfs..."
xbps-reconfigure -a

log "Done. Reboot recommended."
