#!/usr/bin/env bash
# install-pipewire.sh — Automated PipeWire setup on Void Linux
set -euo pipefail

LOG="/tmp/void-tool-pipewire.log"
log() { echo "[pipewire] $*" | tee -a "$LOG"; }

check_installed() {
    local ok=0
    for pkg in pipewire wireplumber alsa-pipewire; do
        if ! xbps-query "$pkg" >/dev/null 2>&1; then
            ok=1
        fi
    done
    if pgrep -x pipewire >/dev/null 2>&1 && pgrep -x wireplumber >/dev/null 2>&1; then
        :
    else
        ok=1
    fi
    return "$ok"
}

if [ "${1:-}" = "--check" ]; then
    if check_installed; then
        pw_ver="$(pipewire --version 2>/dev/null | awk '/Linked/ {print $NF}')" 
        echo "pipewire: ${pw_ver:-?}"
        exit 0
    fi
    echo "pipewire: not installed"
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

# Определяем реального пользователя (через sudo)
REAL_USER="${SUDO_USER:-ig_ro}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"

log "=== void-tool PipeWire installer ==="
log "User: $REAL_USER, Home: $REAL_HOME"

# Определяем DE
DE="unknown"
if [ -f "$REAL_HOME/.config/hypr/hyprland.conf" ] || [ -f "$REAL_HOME/.config/hypr/hyprland.lua" ]; then
    DE="hyprland"
elif [ -f "$REAL_HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml" ]; then
    DE="xfce"
fi
log "Detected DE: $DE"

# ── 1. Remove pulseaudio runit service ──────────────────
if [ -d "/var/service/pulseaudio" ]; then
    log "Removing pulseaudio runit service..."
    rm -rf /var/service/pulseaudio
else
    log "pulseaudio runit service already removed"
fi

# ── 2. Disable pulseaudio autospawn ─────────────────────
PULSE_CONF_DIR="$REAL_HOME/.config/pulse"
mkdir -p "$PULSE_CONF_DIR"
if ! grep -q "autospawn=no" "$PULSE_CONF_DIR/client.conf" 2>/dev/null; then
    log "Blocking pulseaudio autospawn..."
    cat > "$PULSE_CONF_DIR/client.conf" << 'XEOF'
autospawn=no
daemon-binary=/bin/false
XEOF
else
    log "pulseaudio autospawn already blocked"
fi

# ── 3. Remove conflicting user configs ──────────────────
for f in "$REAL_HOME/.config/wireplumber/wireplumber.conf" \
         "$REAL_HOME/.config/pipewire/pipewire.conf.d/10-portal.conf"; do
    if [ -f "$f" ]; then
        log "Removing conflicting config: $f"
        rm -f "$f"
    fi
done

# ── 4. Install PipeWire packages ────────────────────────
PKGS=(pipewire wireplumber alsa-pipewire)
if [ "$DE" = "xfce" ]; then
    PKGS+=(pavucontrol xfce4-pulseaudio-plugin)
fi
log "Installing: ${PKGS[*]}"
xbps-install -Sy "${PKGS[@]}"

# ── 5. Create startup script ────────────────────────────
START_SCRIPT="$REAL_HOME/.config/start-audio.sh"
log "Creating $START_SCRIPT..."
cat > "$START_SCRIPT" << 'XEOF'
#!/bin/bash
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"
export XDG_RUNTIME_DIR=/run/user/1000

if pgrep -x pulseaudio >/dev/null 2>&1; then
    pkill pulseaudio
    sleep 1
fi
rm -f /run/user/1000/pulse/pid

dbus_alive() {
    [ -S /run/user/1000/bus ] || return 1
    timeout 1 dbus-send --session --dest=org.freedesktop.DBus --type=method_call --print-reply \
        /org/freedesktop/DBus org.freedesktop.DBus.ListNames >/dev/null 2>&1
}

if ! dbus_alive; then
    rm -f /run/user/1000/bus
    dbus-daemon --session --address="unix:path=/run/user/1000/bus" --nofork &
    for i in $(seq 1 10); do
        dbus_alive && break
        sleep 0.5
    done
fi

if ! pgrep -x pipewire >/dev/null 2>&1; then
    /usr/bin/pipewire &
    sleep 1
fi

if ! pgrep -x wireplumber >/dev/null 2>&1; then
    /usr/bin/wireplumber &
    sleep 1
fi

if ! pgrep -f "pipewire.*pipewire-pulse.conf" >/dev/null 2>&1; then
    /usr/bin/pipewire -c /usr/share/pipewire/pipewire-pulse.conf &
    sleep 1
fi

for i in $(seq 1 10); do
    if pactl info >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

pactl set-default-sink alsa_output.pci-0000_01_00.1.hdmi-stereo 2>/dev/null
pactl set-sink-volume alsa_output.pci-0000_01_00.1.hdmi-stereo 100% 2>/dev/null
pactl set-sink-mute alsa_output.pci-0000_01_00.1.hdmi-stereo 0 2>/dev/null
XEOF
chmod +x "$START_SCRIPT"

# ── 6. Autostart (DE-agnostic) ──────────────────────────
case "$DE" in
    hyprland)
        HYPR_LUA="$REAL_HOME/.config/hypr/hyprland.lua"
        HYPR_CFG="$REAL_HOME/.config/hypr/hyprland.conf"
        if [ -f "$HYPR_LUA" ] && ! grep -q "start-audio.sh" "$HYPR_LUA" 2>/dev/null; then
            log "Hyprland Lua — add exec-once manually:"
            log "  exec-once = $START_SCRIPT"
        elif [ -f "$HYPR_CFG" ] && ! grep -q "start-audio.sh" "$HYPR_CFG" 2>/dev/null; then
            log "Adding exec-once to $HYPR_CFG..."
            echo "exec-once = $START_SCRIPT" >> "$HYPR_CFG"
            echo "env = PULSE_SERVER,unix:/run/user/1000/pulse/native" >> "$HYPR_CFG"
        else
            log "Autostart already configured for Hyprland"
        fi
        ;;
    xfce)
        AUTOSTART_DIR="$REAL_HOME/.config/autostart"
        mkdir -p "$AUTOSTART_DIR"
        DESKTOP_FILE="$AUTOSTART_DIR/start-audio.desktop"
        if [ ! -f "$DESKTOP_FILE" ]; then
            log "Creating XFCE autostart entry..."
            cat > "$DESKTOP_FILE" << XEOF
[Desktop Entry]
Type=Application
Name=Audio Stack (PipeWire)
Exec=$START_SCRIPT
Hidden=false
NoDisplay=false
X-XFCE-Autostart-Phase=2
X-XFCE-Autostart-Enabled=true
XEOF
            log "XFCE autostart created: $DESKTOP_FILE"
        else
            log "XFCE autostart already exists"
        fi
        ;;
    *)
        log "Unknown DE ($DE) — autostart not configured"
        log "Add $START_SCRIPT to your DE's autostart manually"
        ;;
esac

log ""
log "═══════════════════════════════════════════"
log "Done. Reboot recommended."
log "After reboot:"
log "  pactl info                   # проверить, что PipeWire работает"
log "  pactl list sinks short       # посмотреть устройства вывода"
log "  pavucontrol                  # (для XFCE) GUI громкости"
log "═══════════════════════════════════════════"
