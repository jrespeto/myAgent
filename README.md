# myOpenClaw
 
A containerised remote desktop environment running Ubuntu 25.10 with xrdp, systemd, and the OpenClaw agent. Designed to run on a headless server via Podman.

## Architecture

| Layer | Details |
|-------|---------|
| Base | Ubuntu 25.10 |
| Init | systemd as PID 1 (`/sbin/init`) |
| Service manager | supervisord (manages xrdp, dbus, Xvfb, x11vnc) |
| Remote desktop | xrdp on port 3389 (TLS) |
| Agent display | Xvfb `:99` + x11vnc on port 5901 |
| Desktop | i3 or openbox (selectable at build time) |
| Audio | PipeWire + WirePlumber + pipewire-module-xrdp |
| User session | systemd user instance (via linger + libpam-systemd) |
| Runtime | Podman (rootful) with `privileged: true` on Alpine host |

## Prerequisites

- Podman (rootful) with cgroup v2 enabled on the host
- podman-compose
- An RDP client (e.g. Microsoft Remote Desktop, Remmina)

## Configuration

All options are set as build args and runtime environment variables in `container-compose.yml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `RDP_USER` | `openclaw` | Desktop user username |
| `RDP_PASSWORD` | `openclaw` | Desktop user password |
| `DTE` | `i3` | Desktop environment — `i3` or `openbox` |
| `SOUND` | `true` | Install PipeWire audio stack |
| `HOME` | `/openclaw` | NVM/npm storage directory (separate from user home) |
| `NVM_DIR` | `/openclaw/.nvm` | NVM installation path |

## Build and Run

```sh
# Build and start
podman-compose up -d --build

# Stop
podman-compose down

# View logs
podman-compose logs -f
```

## Connecting

| Protocol | Address | Port |
|----------|---------|------|
| RDP | `<server-ip>` | `33389` |
| VNC (agent display) | `127.0.0.1` | `5901` (localhost only) |

Connect with any RDP client. The session uses TLS with a self-signed certificate — accept the certificate warning on first connect.

## Persistent Data

The user home directory is bind-mounted:

```
./openclaw-home  →  /home/openclaw
```

On first start, `prep.sh` populates it from `/etc/skel` if empty. Subsequent restarts preserve user data. NVM, Node, and npm packages are stored under `/openclaw/` (inside the container image) and symlinked into the home directory.

## User Systemd

The container runs a full user systemd instance for the desktop user, enabling `systemctl --user` and proper user service management. This requires:

- `privileged: true` in the compose file (needed for cgroup delegation on a non-systemd host)
- `libpam-systemd` installed in the image (sets `XDG_RUNTIME_DIR` via PAM)
- Linger enabled for the user at startup via `prep.sh`

PipeWire and WirePlumber are started per-session from `.xsession` and share `XDG_RUNTIME_DIR=/run/user/1001` across both the xrdp session and the agent VNC display.

## Starting the OpenClaw Agent Manually

The OpenClaw agent is not auto-started. To start it:

```sh
supervisorctl start openclaw
```

## Devbox / Nix Setup

A setup script is included at `~/devbox_setup.sh` that installs Nix and Devbox for the current user:

```sh
bash ~/devbox_setup.sh
```

## Troubleshooting

**`systemctl --user` fails with "No such file or directory"**
Check that `libpam-systemd` is installed and that `user@1001.service` started successfully:
```sh
systemctl status user@1001
```

**Black screen on RDP connect**
Check `.xsession` log:
```sh
cat /tmp/xsession.log
```

**No audio**
PipeWire is started per-session. Check that `pipewire`, `wireplumber`, and `pipewire-pulse` are running:
```sh
ps aux | grep -E "pipewire|wireplumber"
```

**Supervisor service status**
```sh
supervisorctl status
```
