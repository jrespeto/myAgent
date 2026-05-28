# Settup up a Alpine System on linode


```bash

echo "podman0" > /etc/hostname

sed -i 's~#~~' /etc/apk/repositories
apk update 
apk upgrade 

reboot

apk add bash procps net-tools bind-tools curl wget tcpdump vim podman podman-compose podman-docker git nftables nfs-utils rsync uuidgen screen jq fuse-overlayfs 

# logs
apk add logrotate syslog-ng 
rc-update add syslog-ng default 

# extras

# for VMware, if running in a VM
apk add open-vm-tools
rc-update add open-vm-tools default
rc-service open-vm-tools start

# for VirtualBox, if running in a VM
# apk add virtualbox-guest-additions
# rc-update add virtualbox-guest-additions default
# rc-service virtualbox-guest-additions start

modprobe tun
echo tun >> /etc/modules

sed -i 's~#firewall_driver = ""~firewall_driver = "nftables"~' /etc/containers/containers.conf 

ln -s /usr/bin/podman-compose /usr/bin/docker-compose
ln -s /var/run/podman/podman.sock /var/run/docker.sock

rc-update add podman default
rc-update add cgroups default
rc-update add nfs default
rc-update add rpcbind default
rc-update add netmount default
rc-update add crond default

rc-service syslog-ng start
rc-service cgroups start
rc-service podman start
rc-service crond start

podman run --rm hello-world
chsh -s /bin/bash


cat > /usr/local/bin/podman-healthchecker <<'EOF'
#!/bin/sh
# Periodically run healthchecks for all running podman containers.
# Replaces the systemd-timer behavior that Alpine lacks.

INTERVAL="${INTERVAL:-10}"

while true; do
    for c in $(podman ps --format '{{.Names}}' 2>/dev/null); do
        podman healthcheck run "$c" >/dev/null 2>&1 || true
    done
    sleep "$INTERVAL"
done
EOF

chmod +x /usr/local/bin/podman-healthchecker

cat > /etc/init.d/podman-healthchecker <<'EOF'
#!/sbin/openrc-run

name="podman-healthchecker"
description="Runs podman healthchecks on a fixed interval (substitute for systemd timers)"

command="/usr/local/bin/podman-healthchecker"
command_background=true
pidfile="/run/${RC_SVCNAME}.pid"
output_log="/var/log/${RC_SVCNAME}.log"
error_log="/var/log/${RC_SVCNAME}.log"

depend() {
  need podman
  after net
}
EOF
chmod +x /etc/init.d/podman-healthchecker

rc-update add podman-healthchecker default
rc-service podman-healthchecker start
rc-service podman-healthchecker status


# Set up a daily cron job to run `podman auto-update` and log the output. 
cat > /etc/periodic/daily/podman-auto-update <<'EOF'
#!/bin/sh
/usr/bin/podman auto-update >/var/log/podman-auto-update.log 2>&1
EOF

chmod +x /etc/periodic/daily/podman-auto-update

```


# 1. Create the group with a specific GID you'll reuse in the container
addgroup -S -g 992 podman

# 2. Fix permissions on the socket and its directory
chgrp podman /run/podman /run/podman/podman.sock
chmod 750 /run/podman
chmod 660 /run/podman/podman.sock

cat > /etc/local.d/podman-socket-perms.start <<'EOF'
#!/bin/sh

# Wait briefly for the socket to appear
for i in 1 2 3 4 5; do
    [ -S /run/podman/podman.sock ] && break
    sleep 1
done
chgrp podman /run/podman /run/podman/podman.sock 2>/dev/null
chmod 750 /run/podman 2>/dev/null
chmod 660 /run/podman/podman.sock 2>/dev/null
EOF
chmod +x /etc/local.d/podman-socket-perms.start
rc-update add local default