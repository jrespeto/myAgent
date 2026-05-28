#!/usr/bin/env bash
set -euo pipefail
# ── prep.sh (openbox) ───────────────────────────────────────────────
# One-shot bootstrap run by supervisord before other services start.
# Exits 0 when done — supervisord will not restart it.

# ── Check if user exists, if not create it ───────────────────────────
if ! id -u "${RDP_USER}" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "${RDP_USER}"
fi

# ── Enable user systemd linger ───────────────────────────────────────
mkdir -p /var/lib/systemd/linger
touch /var/lib/systemd/linger/${RDP_USER}

# ── Set user password at runtime ─────────────────────────────────────
if [[ -z "${RDP_PASSWORD:-}" ]]; then
    echo "ERROR: RDP_PASSWORD env var is not set" >&2
    exit 1
fi
echo "${RDP_USER}:${RDP_PASSWORD}" | chpasswd

# ── Populate home from skel if needed ────────────────────────────────
if [ ! -f "/home/${RDP_USER}/.bashrc" ]; then
    /usr/bin/cp -a /etc/skel/.* "/home/${RDP_USER}/" 2>/dev/null || true
    /usr/bin/cp -a /etc/skel/*  "/home/${RDP_USER}/" 2>/dev/null || true
    chown "${RDP_USER}:${RDP_USER}" "/home/${RDP_USER}/.bashrc"    2>/dev/null || true
    chown "${RDP_USER}:${RDP_USER}" "/home/${RDP_USER}/.profile"   2>/dev/null || true
    chown "${RDP_USER}:${RDP_USER}" "/home/${RDP_USER}/.bash_logout" 2>/dev/null || true
    chown "${RDP_USER}:${RDP_USER}" "/home/${RDP_USER}/.xsession"  2>/dev/null || true
    chown "${RDP_USER}:${RDP_USER}" "/home/${RDP_USER}/*.sh" 2>/dev/null || true
fi

# ── Symlink nvm / npm into user home ─────────────────────────────────
for f in .nvm .npm-global .npm .npmrc; do
    unlink "/home/${RDP_USER}/${f}" 2>/dev/null || true
    if [ ! -e "/home/${RDP_USER}/${f}" ]; then
        ln -s "/${RDP_USER}/${f}" "/home/${RDP_USER}/${f}"
        chown -h "${RDP_USER}:${RDP_USER}" "/home/${RDP_USER}/${f}" 2>/dev/null || true
    fi
done

# ── Ensure Chrome crashpad dir exists and is owned by the user ────────
if [ ! -d "/home/${RDP_USER}/.config/google-chrome/Crashpad" ]; then
    mkdir -p "/home/${RDP_USER}/.config/google-chrome/Crashpad"
    chown -R "${RDP_USER}:${RDP_USER}" "/home/${RDP_USER}/.config/google-chrome/Crashpad"
fi

# ── Fix ownership of mounted volumes ────────────────────────────────
mkdir -p "/home/${RDP_USER}"
chown -R "${RDP_USER}:${RDP_USER}" "/home/${RDP_USER}" 2>/dev/null || true

# ── Ensure openbox config exists (fresh mount) ──────────────────────
if [ ! -f "/home/${RDP_USER}/.config/openbox/rc.xml" ]; then
    mkdir -p "/home/${RDP_USER}/.config/openbox"
    cp /etc/xdg/openbox/rc.xml   "/home/${RDP_USER}/.config/openbox/rc.xml"
    cp /etc/xdg/openbox/menu.xml "/home/${RDP_USER}/.config/openbox/menu.xml"
    chown -R "${RDP_USER}:${RDP_USER}" "/home/${RDP_USER}/.config/openbox"
fi

# ── Ensure xsession exists (fresh mount) ─────────────────────────────
if [ ! -f "/home/${RDP_USER}/.xsession" ]; then
    cp /etc/skel/.xsession "/home/${RDP_USER}/.xsession" 2>/dev/null || true
    chown "${RDP_USER}:${RDP_USER}" "/home/${RDP_USER}/.xsession" 2>/dev/null || true
fi

# ── Clean stale Chrome locks ──────────────────────────────────────────
rm -f "/home/${RDP_USER}/.config/google-chrome/SingletonLock" \
    "/home/${RDP_USER}/.config/google-chrome/SingletonSocket" \
    "/home/${RDP_USER}/.config/google-chrome/SingletonCookie" 2>/dev/null || true

# ── Patch startwm.sh so xrdp calls our xsession ─────────────────────
XSESSION="/home/${RDP_USER}/.xsession"
cat > /etc/xrdp/startwm.sh << EOF
#!/bin/sh
exec ${XSESSION}
EOF
chmod +x /etc/xrdp/startwm.sh

# ── Prepare xrdp runtime dirs ───────────────────────────────────────
mkdir -p /var/run/xrdp /var/log/xrdp /tmp/.X11-unix
chown xrdp:xrdp /var/run/xrdp 2>/dev/null || true
chmod 1777 /tmp /tmp/.X11-unix

echo "=== prep.sh (openbox) finished ==="
exit 0
