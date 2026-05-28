#!/bin/sh
# ── xsession.sh (openbox) ───────────────────────────────────────────
# Shared session script for both xrdp (:0) and VNC agent (:99) displays.
# xrdp calls this via startwm.sh for the user's RDP desktop.
exec > /tmp/xsession.log 2>&1
set -x

echo "=== xsession started at $(date) ==="
echo "=== DISPLAY=$DISPLAY USER=$(whoami) ==="

# Ensure sane environment — sesman may start us with minimal env
export HOME="/home/$USER"
export PATH="/home/$USER/.nix-profile/bin:/home/$USER/.nix-profile/sbin:/home/$USER/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export LANG="${LANG:-C.UTF-8}"

# xrdp sets DISPLAY as :10.0 — strip the screen suffix
export DISPLAY="${DISPLAY%%.*}"

# Wait for the X socket to appear
for i in $(seq 1 10); do
    [ -e "/tmp/.X11-unix/X${DISPLAY#:}" ] && break
    sleep 0.2
done

if [ ! -e "/tmp/.X11-unix/X${DISPLAY#:}" ]; then
    echo "=== ERROR: X socket never appeared ===" && exit 1
fi

unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

export XDG_RUNTIME_DIR=/run/user/$(id -u)
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Clean stale PipeWire/Pulse locks from previous sessions
rm -f "$XDG_RUNTIME_DIR"/pipewire-0.lock "$XDG_RUNTIME_DIR"/pipewire-0
rm -rf "$XDG_RUNTIME_DIR/pulse"

# Use the user systemd bus if available (linger), else fall back to dbus-launch
if [ -S "$XDG_RUNTIME_DIR/bus" ]; then
    export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
else
    eval "$(dbus-launch --sh-syntax)"
    export DBUS_SESSION_BUS_ADDRESS
fi

# ── PipeWire audio stack via user systemd ───────────────────────────
if systemctl --user is-system-running >/dev/null 2>&1; then
    systemctl --user start pipewire wireplumber pipewire-pulse
else
    pipewire &
    wireplumber &
    pipewire-pulse &
fi

# ── Window manager ───────────────────────────────────────────────────
openbox --config-file "$HOME/.config/openbox/rc.xml" &
tint2 &

sleep 0.5

# ── Audio setup (background) ────────────────────────────────────────
(
    for i in $(seq 1 20); do
        pw-cli info >/dev/null 2>&1 && break
        sleep 0.25
    done

    SOCKET_DIR="${XRDP_SOCKET_PATH:-/run/xrdp/sockdir}"
    for i in $(seq 1 30); do
        [ -e "${SOCKET_DIR}/xrdp_chansrv_audio_out_socket_${DISPLAY#:}" ] && break
        sleep 0.5
    done

    XRDP_LOADER="/usr/libexec/pipewire-module-xrdp/load_pw_modules.sh"
    [ -x "$XRDP_LOADER" ] && "$XRDP_LOADER" >/dev/null 2>&1

    sleep 0.5
    pactl set-sink-mute @DEFAULT_SINK@ 0 2>/dev/null
    pactl set-sink-volume @DEFAULT_SINK@ 100% 2>/dev/null
    echo "=== Audio setup complete ===" >> /tmp/xsession.log
) &

# ── Dynamic resize helper ───────────────────────────────────────────
(
    LAST_RES=""
    while true; do
        CUR_RES=$(xrandr 2>/dev/null | grep '\*' | awk '{print $1}' | head -1)
        if [ -n "$CUR_RES" ] && [ "$CUR_RES" != "$LAST_RES" ]; then
            LAST_RES="$CUR_RES"
            sleep 0.3
            openbox --reconfigure 2>/dev/null
        fi
        sleep 2
    done
) &

echo "=== xsession ready, waiting ==="

# Keep session alive — wait for openbox
wait
