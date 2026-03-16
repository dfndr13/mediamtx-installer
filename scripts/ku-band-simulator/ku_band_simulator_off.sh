#!/bin/bash
# Turn OFF Ku-band simulator. Run on the same box as _on.sh. Requires root.
# Usage: sudo ./ku_band_simulator_off.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${SCRIPT_DIR}/ku_band_simulator.conf"

if [ ! -f "$CONFIG" ]; then
  INTERFACE="${INTERFACE:-eth0}"
else
  source "$CONFIG"
  INTERFACE="${INTERFACE:-eth0}"
fi

# Remove netem from ifb0 first, then ingress from the real interface
tc qdisc del dev ifb0 root 2>/dev/null || true
tc qdisc del dev "$INTERFACE" ingress 2>/dev/null || true

echo "Ku-band simulator OFF."
