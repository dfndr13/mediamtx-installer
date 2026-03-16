#!/bin/bash
# Turn ON Ku-band-like impairment for incoming traffic from the sending MediaMTX.
# Run on the RECEIVER box (the one that pulls the stream as external source).
# Requires root. Usage: sudo ./ku_band_simulator_on.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${SCRIPT_DIR}/ku_band_simulator.conf"

if [ ! -f "$CONFIG" ]; then
  echo "Missing $CONFIG. Copy ku_band_simulator.conf.example and set SOURCE_IP and INTERFACE."
  exit 1
fi
# shellcheck source=ku_band_simulator.conf
source "$CONFIG"

if [ -z "$SOURCE_IP" ] || [ -z "$INTERFACE" ]; then
  echo "Set SOURCE_IP (sending MediaMTX IP) and INTERFACE (e.g. eth0) in $CONFIG"
  exit 1
fi

# Ku-band-like: high RTT, jitter, some loss (tweak as needed)
DELAY_MS="${DELAY_MS:-600}"
JITTER_MS="${JITTER_MS:-100}"
LOSS_PCT="${LOSS_PCT:-1}"

# Already on?
if tc qdisc show dev "$INTERFACE" | grep -q ingress; then
  echo "Simulator already ON (ingress on $INTERFACE). Run ku_band_simulator_off.sh first."
  exit 0
fi

modprobe ifb 2>/dev/null || true
ip link set dev ifb0 up 2>/dev/null || true

# Redirect ingress from SOURCE_IP to ifb0
tc qdisc add dev "$INTERFACE" ingress
tc filter add dev "$INTERFACE" parent ffff: protocol ip u32 match ip src "$SOURCE_IP" action mirred egress redirect dev ifb0

# Apply impairment on ifb (affects the redirected incoming traffic)
tc qdisc add dev ifb0 root netem delay "${DELAY_MS}ms" "${JITTER_MS}ms" loss "${LOSS_PCT}%"

echo "Ku-band simulator ON: traffic from $SOURCE_IP -> $INTERFACE delayed ${DELAY_MS}ms ±${JITTER_MS}ms, ${LOSS_PCT}% loss."
