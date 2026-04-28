#!/bin/bash

# MediaMTX Docker Installation Script for Ubuntu 22.04
# Installs MediaMTX as a Docker container with web-based configuration editor
# Supports standalone and CloudTAK coexistence deployments
# Part of dfndr13/mediamtx-installer (Docker-compatible fork)

set -e

export DEBIAN_FRONTEND=noninteractive

echo "=========================================="
echo "MediaMTX Docker Installer (Ubuntu 22.04)"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

if pgrep -f "/usr/bin/unattended-upgrade$" > /dev/null; then
    echo ""
    echo "************************************************************"
    echo "  YOUR OPERATING SYSTEM IS CURRENTLY DOING UPGRADES"
    echo "  We need to wait until this is done."
    echo "************************************************************"
    echo ""
    SECONDS=0
    while pgrep -f "/usr/bin/unattended-upgrade$" > /dev/null; do
        printf "\rWaiting... %02d:%02d elapsed" $((SECONDS/60)) $((SECONDS%60))
        sleep 2
    done
    echo ""
    echo "✓ Updates complete. Starting installation..."
    echo ""
    sleep 2
else
    echo "✓ No system upgrades in progress, continuing..."
    echo ""
fi

echo "=========================================="
echo "Step 1: Checking Docker"
echo "=========================================="

if ! command -v docker &> /dev/null; then
    echo "Docker not installed. Installing..."
    apt-get update -qq
    apt-get install -y ca-certificates curl > /dev/null 2>&1
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -qq
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1
    systemctl enable docker
    systemctl start docker
    echo "✓ Docker installed"
else
    echo "✓ Docker already installed: $(docker --version)"
fi

echo ""
echo "=========================================="
echo "Step 2: Detecting Existing Services"
echo "=========================================="

CLOUDTAK_MEDIA_RUNNING=false

if docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'cloudtak-media'; then
    CLOUDTAK_MEDIA_RUNNING=true
    echo "⚠️  cloudtak-media-1 detected (CloudTAK bundled MediaMTX)."
    echo "    Port conflicts possible on 8888/8890/9997."
else
    echo "✓ No CloudTAK media container detected."
fi

echo ""
echo "=========================================="
echo "Step 3: Port Configuration"
echo "=========================================="
echo ""

if [ "$CLOUDTAK_MEDIA_RUNNING" = true ]; then
    echo "CloudTAK's bundled MediaMTX occupies ports that conflict with defaults."
    echo ""
    echo "  [1] Standalone mode   — default ports (8888/8890)"
    echo "      Use if CloudTAK is NOT on this host."
    echo ""
    echo "  [2] Coexistence mode  — remapped ports (8980/8981)"
    echo "      Use if CloudTAK IS on this host."
    echo ""
    read -p "Select mode [1/2]: " PORT_MODE
else
    echo "✓ Using default ports."
    PORT_MODE=1
fi

case $PORT_MODE in
    2)
        HLS_PORT=8980
        SRT_PORT=8981
        RTSP_PORT=8554
        RTMP_PORT=1935
        RTP_PORT=8000
        RTCP_PORT=8001
        WEBRTC_PORT=8189
        API_HOST_PORT=9907
        echo "✓ Coexistence mode — remapped ports: HLS=$HLS_PORT SRT=$SRT_PORT"
        ;;
    *)
        HLS_PORT=8888
        SRT_PORT=8890
        RTSP_PORT=8554
        RTMP_PORT=1935
        RTP_PORT=8000
        RTCP_PORT=8001
        WEBRTC_PORT=8189
        API_HOST_PORT=9907
        echo "✓ Standalone mode — default ports."
        ;;
esac

echo ""
echo "=========================================="
echo "Step 4: Generating Credentials"
echo "=========================================="

WEBEDITOR_USER="webeditor"
WEBEDITOR_PASS=$(openssl rand -base64 16 | tr -d '/+=\n' | head -c 20)
HLS_PASS=$(openssl rand -base64 16 | tr -d '/+=\n' | head -c 16)

echo "✓ Credentials generated (saved to /opt/mediamtx/webeditor.env)"

echo ""
echo "=========================================="
echo "Step 5: Creating Directory Structure"
echo "=========================================="

mkdir -p /opt/mediamtx/config
mkdir -p /opt/mediamtx/recordings
echo "✓ /opt/mediamtx/config"
echo "✓ /opt/mediamtx/recordings"

echo ""
echo "=========================================="
echo "Step 6: Writing MediaMTX Configuration"
echo "=========================================="

cat > /opt/mediamtx/config/mediamtx.yml << CONFIGEOF
logLevel: info
logDestinations: [stdout]
logStructured: no
logFile: mediamtx.log
sysLogPrefix: mediamtx
readTimeout: 10s
writeTimeout: 10s
writeQueueSize: 1024
udpMaxPayloadSize: 1472
udpReadBufferSize: 0
runOnConnect:
runOnConnectRestart: no
runOnDisconnect:
authMethod: internal
authInternalUsers:
- user: ${WEBEDITOR_USER}
  pass: ${WEBEDITOR_PASS}
  ips: ['127.0.0.1', '::1']
  permissions:
  - action: read
  - action: publish
  - action: api
- user: hlsviewer
  pass: ${HLS_PASS}
  ips: []
  permissions:
  - action: read
- user: any
  pass: ''
  ips: []
  permissions:
  - action: read
    path: teststream
api: yes
apiAddress: :9997
apiEncryption: no
apiServerKey:
apiServerCert:
apiAllowOrigins: ['*']
apiTrustedProxies: []
metrics: no
metricsAddress: :9998
pprof: no
pprofAddress: :9999
playback: no
playbackAddress: :9996
rtsp: yes
rtspTransports: [tcp]
rtspEncryption: "no"
rtspAddress: :8554
rtspsAddress: :8322
rtpAddress: :8000
rtcpAddress: :8001
multicastIPRange: 224.1.0.0/16
multicastRTPPort: 8002
multicastRTCPPort: 8003
rtspServerKey:
rtspServerCert:
rtspAuthMethods: [basic]
rtmp: no
rtmpAddress: :1935
rtmpEncryption: "no"
rtmpsAddress: :1936
rtmpServerKey:
rtmpServerCert:
hls: yes
hlsAddress: :8888
hlsEncryption: no
hlsServerKey:
hlsServerCert:
hlsAllowOrigins: ['*']
hlsTrustedProxies: ['127.0.0.1']
hlsAlwaysRemux: yes
hlsVariant: mpegts
hlsSegmentCount: 7
hlsSegmentDuration: 3s
hlsPartDuration: 200ms
hlsSegmentMaxSize: 50M
hlsDirectory: ''
hlsMuxerCloseAfter: 60s
webrtc: no
webrtcAddress: :8889
webrtcEncryption: no
webrtcLocalUDPAddress: :8189
webrtcLocalTCPAddress: ''
webrtcIPsFromInterfaces: yes
webrtcIPsFromInterfacesList: []
webrtcAdditionalHosts: []
webrtcICEServers2: []
webrtcHandshakeTimeout: 10s
webrtcTrackGatherTimeout: 2s
webrtcSTUNGatherTimeout: 5s
srt: yes
srtAddress: :8890
pathDefaults:
  source: publisher
  sourceOnDemand: no
  sourceOnDemandStartTimeout: 10s
  sourceOnDemandCloseAfter: 10s
  maxReaders: 0
  fallback:
  useAbsoluteTimestamp: false
  record: no
  recordPath: /recordings/%path_%Y-%m-%d_%H-%M-%S-%f
  recordFormat: mpegts
  recordPartDuration: 1s
  recordMaxPartSize: 50M
  recordSegmentDuration: 1h
  recordDeleteAfter: 720h
  overridePublisher: yes
  rtspTransport: automatic
  rtspAnyPort: no
  rtspDemuxMpegts: true
paths:
  teststream:
    record: no
  all_others:
CONFIGEOF

echo "✓ /opt/mediamtx/config/mediamtx.yml written"

echo ""
echo "=========================================="
echo "Step 7: Writing Docker Compose File"
echo "=========================================="

cat > /opt/mediamtx/docker-compose.yml << COMPOSEEOF
services:
  mediamtx:
    image: bluenviron/mediamtx:latest-ffmpeg
    container_name: mediamtx
    restart: unless-stopped
    volumes:
      - /opt/mediamtx/config/mediamtx.yml:/mediamtx.yml:rw
      - /opt/mediamtx/recordings:/recordings
    ports:
      - "${RTSP_PORT}:8554/tcp"
      - "${RTP_PORT}:8000/udp"
      - "${RTCP_PORT}:8001/udp"
      - "${RTMP_PORT}:1935/tcp"
      - "${HLS_PORT}:8888/tcp"
      - "${SRT_PORT}:8890/udp"
      - "${WEBRTC_PORT}:8189/udp"
      - "127.0.0.1:${API_HOST_PORT}:9997/tcp"
COMPOSEEOF

echo "✓ /opt/mediamtx/docker-compose.yml written"

echo ""
echo "=========================================="
echo "Step 8: Saving Credentials"
echo "=========================================="

cat > /opt/mediamtx/webeditor.env << ENVEOF
WEBEDITOR_USER=${WEBEDITOR_USER}
WEBEDITOR_PASS=${WEBEDITOR_PASS}
HLS_PASS=${HLS_PASS}
API_HOST_PORT=${API_HOST_PORT}
HLS_PORT=${HLS_PORT}
SRT_PORT=${SRT_PORT}
ENVEOF
chmod 600 /opt/mediamtx/webeditor.env
echo "✓ Saved to /opt/mediamtx/webeditor.env"

echo ""
echo "=========================================="
echo "Step 9: Starting MediaMTX Container"
echo "=========================================="

cd /opt/mediamtx
docker compose up -d

echo "Waiting for container to start..."
sleep 5

if docker ps --format '{{.Names}}' | grep -q '^mediamtx$'; then
    echo "✓ MediaMTX container is running"
else
    echo "ERROR: MediaMTX container failed to start"
    echo "Check: docker logs mediamtx"
    exit 1
fi

echo ""
echo "=========================================="
echo "Step 10: Installing Web Editor Service"
echo "=========================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEBEDITOR_DIR="$(dirname "$SCRIPT_DIR")"

if [ ! -f "$WEBEDITOR_DIR/mediamtx_config_editor.py" ]; then
    echo "ERROR: mediamtx_config_editor.py not found at $WEBEDITOR_DIR"
    echo "Clone the repo to /opt/mediamtx-webeditor first:"
    echo "  git clone https://github.com/dfndr13/mediamtx-installer /opt/mediamtx-webeditor"
    exit 1
fi

echo "✓ Web editor found at: $WEBEDITOR_DIR"

apt-get install -y python3 python3-pip > /dev/null 2>&1
pip3 install flask pyyaml requests --break-system-packages > /dev/null 2>&1
echo "✓ Python dependencies installed"

cat > /etc/systemd/system/mediamtx-webeditor.service << SVCEOF
[Unit]
Description=MediaMTX Web Configuration Editor
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 ${WEBEDITOR_DIR}/mediamtx_config_editor.py
WorkingDirectory=${WEBEDITOR_DIR}
Restart=always
RestartSec=5
User=root
Environment=MEDIAMTX_CONFIG=/opt/mediamtx/config/mediamtx.yml
Environment=MEDIAMTX_API_URL=http://${WEBEDITOR_USER}:${WEBEDITOR_PASS}@127.0.0.1:${API_HOST_PORT}
Environment=WEBEDITOR_PORT=5100
Environment=MEDIAMTX_USE_DOCKER=1
Environment=MEDIAMTX_CONTAINER_NAME=mediamtx
Environment=MEDIAMTX_COMPOSE_DIR=/opt/mediamtx

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable mediamtx-webeditor
systemctl start mediamtx-webeditor
sleep 3

if systemctl is-active --quiet mediamtx-webeditor; then
    echo "✓ Web editor service running"
else
    echo "ERROR: Web editor failed to start"
    echo "Check: journalctl -u mediamtx-webeditor -n 50"
    exit 1
fi

echo ""
echo "=========================================="
echo "Step 11: Configuring Firewall"
echo "=========================================="

if command -v ufw &> /dev/null; then
    ufw allow ${RTSP_PORT}/tcp  > /dev/null 2>&1
    ufw allow ${HLS_PORT}/tcp   > /dev/null 2>&1
    ufw allow ${SRT_PORT}/udp   > /dev/null 2>&1
    ufw allow ${RTP_PORT}/udp   > /dev/null 2>&1
    ufw allow ${RTCP_PORT}/udp  > /dev/null 2>&1
    echo "✓ UFW rules added (API port is loopback-only, no rule needed)"
else
    echo "UFW not found — configure firewall manually"
    echo "  Allow: ${RTSP_PORT}/tcp, ${HLS_PORT}/tcp, ${SRT_PORT}/udp"
fi

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "  MediaMTX container: running"
echo "  Web editor:         http://localhost:5100"
echo "  Config:             /opt/mediamtx/config/mediamtx.yml"
echo "  Recordings:         /opt/mediamtx/recordings/"
echo "  Credentials:        /opt/mediamtx/webeditor.env"
echo ""
echo "  Streaming ports:"
echo "    RTSP:  ${RTSP_PORT}/tcp"
echo "    HLS:   ${HLS_PORT}/tcp"
echo "    SRT:   ${SRT_PORT}/udp"
echo "    RTMP:  ${RTMP_PORT}/tcp  (disabled by default)"
echo ""
if [ "$PORT_MODE" = "2" ]; then
    echo "  ⚠️  Coexistence mode active — ports remapped to avoid CloudTAK conflicts."
    echo "     Update Caddy reverse_proxy to use port ${HLS_PORT} for HLS."
    echo ""
fi
echo "  Next step: run the Caddy installer"
echo "    ubuntu-22.04/Ubuntu_22.04_Install_MediaMTX_Docker_Caddy.sh"
echo ""
echo "  Container commands:"
echo "    Logs:    docker logs mediamtx -f"
echo "    Restart: docker compose -f /opt/mediamtx/docker-compose.yml restart"
echo "    Stop:    docker compose -f /opt/mediamtx/docker-compose.yml down"
echo ""
