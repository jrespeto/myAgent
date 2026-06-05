FROM ubuntu:25.10

ENV DEBIAN_FRONTEND=noninteractive

EXPOSE 3389
ARG RDP_USER=openclaw
ARG RDP_PASSWORD=openclaw
ARG HOME=/${RDP_USER}
ARG NVM_DIR=/${RDP_USER}/.nvm
ARG DTE=openbox
ARG SOUND=true

USER root

# ── System packages ──────────────────────────────────────────────────────────
RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends ca-certificates curl gnupg; \
  mkdir -p /etc/apt/keyrings; \
  echo "deb [arch=amd64 trusted=yes] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list; \
  echo 'deb [trusted=yes] https://pkgs.netbird.io/debian stable main' > /etc/apt/sources.list.d/netbird.list; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    systemd \
    netbird \
    netbird-ui \
    openssh-server \
    systemd-sysv \
    libpam-systemd \
    ffmpeg \
    uidmap \
    supervisor \
    xrdp \
    xorgxrdp \
    xvfb \
    x11vnc \
    dbus \
    dbus-x11 \
    xauth \
    x11-xserver-utils \
    openssl \
    wmctrl \
    sudo \
    wget \
    git \
    vim \
    screen \
    tmux \
    htop \
    jq \
    yq \
    xdotool \
    scrot \
    bat \
    fd-find \
    ripgrep \
    ethtool \
    iproute2 \
    lsof \
    build-essential \
    net-tools \
    xfonts-encodings \
    fonts-droid-fallback \
    fonts-urw-base35 \
    xfonts-utils \
    fonts-dejavu \
    fonts-liberation \
    fonts-noto-core \
    fonts-noto-color-emoji; \
  # Sound support (optional) \
  if [ "$SOUND" = "true" ]; then \
    apt-get install -y --no-install-recommends \
      pipewire \
      pipewire-pulse \
      pipewire-module-xrdp \
      wireplumber \
      pulseaudio-utils; \
  fi; \
  # Desktop environment \
  if [ "$DTE" = "i3" ]; then \
    apt-get install -y --no-install-recommends i3 j4-dmenu-desktop dmenu i3lock; \
  elif [ "$DTE" = "openbox" ]; then \
    apt-get install -y --no-install-recommends openbox tint2 obconf; \
  fi; \
  # GUI apps \
  apt-get install -y --no-install-recommends \
    lxterminal \
    tigervnc-viewer \
    google-chrome-stable; \
  rm -f /lib/systemd/system/multi-user.target.wants/* \
      /etc/systemd/system/*.wants/* \
      /lib/systemd/system/local-fs.target.wants/* \
      /lib/systemd/system/sockets.target.wants/*udev* \
      /lib/systemd/system/sockets.target.wants/*initctl* \
      /lib/systemd/system/basic.target.wants/* && \
  mkdir -p /etc/systemd/system/multi-user.target.wants && \
  ln -sf /lib/systemd/system/supervisor.service /etc/systemd/system/multi-user.target.wants/supervisor.service && \
  ln -sf /lib/systemd/system/systemd-logind.service /etc/systemd/system/multi-user.target.wants/systemd-logind.service && \
  # ln -sf /lib/systemd/system/dbus.service /etc/systemd/system/multi-user.target.wants/dbus.service && \
  # ln -sf /lib/systemd/system/pipewire.service /etc/systemd/system/multi-user.target.wants/pipewire.service && \
  # ln -sf /lib/systemd/system/pipewire-pulse.service /etc/systemd/system/multi-user.target.wants/pipewire-pulse.service && \
  # ln -sf /lib/systemd/system/wireplumber.service /etc/systemd/system/multi-user.target.wants/wireplumber.service && \
  ln -sf /lib/systemd/system/ssh.service /etc/systemd/system/multi-user.target.wants/ssh.service && \
  mkdir -p /etc/systemd/system/supervisor.service.d && \
  printf '[Service]\nPassEnvironment=RDP_USER RDP_PASSWORD\n' > /etc/systemd/system/supervisor.service.d/env.conf; \
  apt-get autoremove -y; \
  apt-get clean; \
  rm -rf /var/lib/apt/lists/*; \
  fc-cache -fv

# ── xrdp config ──────────────────────────────────────────────────────────────
RUN sed -i \
    -e 's/^security_layer=.*/security_layer=tls/' \
    -e 's/^crypt_level=.*/crypt_level=low/' \
    -e 's/^#tcp_send_buffer_bytes=.*/tcp_send_buffer_bytes=65536/' \
    -e 's/^#tcp_recv_buffer_bytes=.*/tcp_recv_buffer_bytes=65536/' \
    -e 's/^max_bpp=.*/max_bpp=16/' \
    /etc/xrdp/xrdp.ini \
  && echo "bulk_compression=true" >> /etc/xrdp/xrdp.ini \
  && echo "new_cursors=true" >> /etc/xrdp/xrdp.ini

# Generate TLS cert for xrdp
RUN openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout /etc/xrdp/key.pem \
    -out    /etc/xrdp/cert.pem \
    -days   3650 \
    -subj   "/CN=${RDP_USER}" \
  && chmod 640 /etc/xrdp/key.pem \
  && chown root:xrdp /etc/xrdp/key.pem

# ── Copy DTE-specific configs from scratch stage ─────────────────────────────
COPY --chown=root:root configs/supervisor/ /etc/supervisor/
COPY --chown=root:root configs/${DTE}/skel/ /etc/skel/
COPY --chown=root:root configs/${DTE}/prep.sh /prep.sh
COPY --chown=root:root configs/${DTE}/supervisor/ /etc/supervisor/

COPY --chown=root:root skel/ /etc/skel/

RUN printf 'export XDG_RUNTIME_DIR=/run/user/$(id -u)\nmkdir -p "$XDG_RUNTIME_DIR"\nchmod 700 "$XDG_RUNTIME_DIR"\n' \
  > /etc/profile.d/xdg-runtime.sh && \
  chmod 644 /etc/profile.d/xdg-runtime.sh

# ── Create app user ──────────────────────────────────────────────────────────
RUN chmod +x /prep.sh; \
  chmod +x /etc/skel/.xsession; \
  chmod +x /etc/skel/*.sh; \
  useradd -m -s /bin/bash ${RDP_USER}; \
  groupadd -g 2999 podman && usermod -aG podman ${RDP_USER}; \
  echo "${RDP_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${RDP_USER}; \
  chmod 0440 /etc/sudoers.d/${RDP_USER}; \
  usermod -a -G audio ${RDP_USER}; \
  mkdir -p /run/dbus /var/log/supervisor; \
  mkdir /${RDP_USER}; \
  chmod 755 /${RDP_USER}; \
  chown -R ${RDP_USER}:${RDP_USER} /${RDP_USER}; \
  mkdir -p /var/lib/systemd/linger; \
  touch /var/lib/systemd/linger/${RDP_USER}; \
  USER_UID=$(id -u ${RDP_USER}); \
  mkdir -p /run/user/${USER_UID}; \
  chmod 700 /run/user/${USER_UID}; \
  chown ${RDP_USER}:${RDP_USER} /run/user/${USER_UID}
    
USER ${RDP_USER}

# Download and install nvm, node, and openclaw
RUN /etc/skel/setup_nvm.sh && \
    /etc/skel/setup_${RDP_USER}.sh image-build && \
    /etc/skel/clean_up.sh

USER root

ENTRYPOINT ["/sbin/init"]
