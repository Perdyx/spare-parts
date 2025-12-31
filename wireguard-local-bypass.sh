#!/usr/bin/env bash

# Author: Per
# Description: Adds a route so LAN traffic from the VPN subnet bypasses the external WireGuard provider. Designed for systems using NetworkManager.
# Usage: sudo ./wg.sh path/to/wg0.conf
# Note: This script requires root in order to edit the routing table and will automatically prompt you for your credentials. Adjust the $ROUTE variable to match your VPN subnet. Routes are cleared automatically on reboot, in most cases.

ROUTE="10.10.10.0/24" # Adjust to match your VPN subnet
CONFIG="$1"

add_route() {
    echo "Adding route: $ROUTE via $gw dev $dev"
    sudo ip route add "$ROUTE" via "$gw" dev "$dev"

    echo "Route added. To remove the route, run:"
    echo "sudo ip route del $ROUTE via $gw dev $dev"
}

check_route_exists() {
    ip route show "$ROUTE" | grep -q "via $gw dev $dev"
}

cleanup() {
    echo
    echo "Disconnecting WireGuard..."
    wg-quick down "$CONFIG" || echo "WireGuard takedown failed."
    echo "WireGuard takedown successful."
    exit 0
}

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run from the root user."
    exit 1
fi

echo "Gathering network information..."

gw=$(ip route show default | awk '/default/ {print $3}')
dev=$(ip route show default | awk '/default/ {print $5}')

echo "Default gateway: $gw"
echo "Default interface: $dev"

if ! check_route_exists; then
    add_route
else
    echo "Route already exists: $ROUTE via $gw dev $dev"
fi

echo -e "Ready!\nStarting WireGuard..."
wg-quick up "$CONFIG"
if [ $? -ne 0 ]; then
    echo "WireGuard failed to start. Exiting."
    exit 1
fi

# Trap (SIGINT, SIGTERM) and block until Ctrl+C
trap cleanup INT TERM
echo -e "WireGuard connection successful.\nPress Ctrl+C at any time to disconnect..."
while :; do
    sleep 1
done
