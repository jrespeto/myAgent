#!/bin/sh

# Start NetBird in the foreground so supervisord can manage it as a long-lived process.
netbird up --foreground-mode \
  --setup-key "$NB_SETUP_KEY" \
  --management-url "$NB_MANAGEMENT_URL" \
  --allow-server-ssh --enable-ssh-root &
NB_PID=$!

# Wait until the WireGuard interface (wt0) is up and has an IP before
# touching routing rules — NetBird sets up its policy rules during connect,
# and we want our rule applied AFTER, so it isn't flushed/overridden.
until ip addr show wt0 2>/dev/null | grep -q 'inet '; do
  sleep 1
done

# Fix asymmetric routing for inbound connections to published ports.
#
# Problem: NetBird installs an ip rule (priority 105) that consults the main
# routing table but suppresses its default route, then a rule (priority 110)
# that sends everything else into NetBird's own table. If the host (or any
# peer) reaches us on an IP that isn't on a connected subnet — e.g. the host
# at 192.168.1.x hitting a published port — our reply gets pulled into the
# WireGuard tunnel instead of going back out eth0 to the host. Connection
# hangs.
#
# Fix: add a rule at priority 90 (evaluated BEFORE NetBird's rules) that says
# "if this packet is sourced from our local bridge subnet, use the main table
# normally" — which still has the original `default via <gateway> dev eth0`.
# That sends replies back out eth0 the way they came in.
#
# We read the connected subnet straight from the kernel rather than hardcoding
# it, so this works whether the container bridge is 10.89.0.0/24, 172.17.0.0/16,
# or anything else Docker/Podman happens to assign. Handles multiple subnets too.
# The `|| true` keeps a re-run (e.g. supervisord restart) from failing on a
# duplicate add.
ip -o -f inet route show dev eth0 scope link | awk '{print $1}' | while read -r subnet; do
  ip rule add from "$subnet" table main priority 90 2>/dev/null || true
done

# Block on NetBird's PID so the script's lifetime tracks the daemon's.
# If NetBird exits, this script exits, and supervisord will restart it
# (which also re-applies the ip rule above).
wait "$NB_PID"