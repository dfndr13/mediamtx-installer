#!/bin/bash

# Caddy Setup Script for MediaMTX Docker Deployment (Ubuntu 22.04)
# Provides HTTPS via Let's Encrypt, web editor proxy, and SSL cert paths
# for RTSPS/HLS encryption in the Docker-based MediaMTX deployment.
# Part of dfndr13/mediamtx-installer (Docker-compatible fork)
#
# ⚠️  ALPHA — under active development

set -e

export DEBIAN_FRONTEND=noninteractive

echo "=========================================="
echo "Caddy Setup for MediaMTX Docker (Ubuntu 22.04)"
echo "=========================================="
echo ""

# ==========================================
# Root check
# ==========================================
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# ==========================================
# Check MediaMTX Docker deployment exists
# ==========================================
if [ ! -f /opt/mediamtx/config/mediamtx.yml ]; then
    echo "ERROR: /opt/mediamtx/config/mediamtx.yml not found."
    echo "Run the Docker installer first:"
    echo "  sudo ./ubuntu-22.04/Ubuntu_22.04_Install_MediaMTX_Docker.sh"
    exit 1
fi

if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^mediamtx$'; then
    echo "ERROR: MediaMTX container is not running."
    echo "Start it with: docker compose -f /opt/mediamtx/docker-compose.yml up -d"
    exit 1
fi

# ==========================================
# Unattended-Upgrade Detection
# ==========================================
if pgrep -f "/usr/bin/unattended-upgrade$" > /dev/null; then
    echo ""
    echo "************************************************************"
    echo "  YOUR OPERATING SYSTEM IS CURRENTLY DOING UPGRADES"
    echo "  Waiting until complete..."
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

# ==========================================
# Step 1: Domain Configuration
# ==========================================
echo "=========================================="
echo "Step 1: Domain Configuration"
echo "=========================================="
echo ""
echo "Enter the domain name for your MediaMTX server."
echo "Examples: video.yourdomain.com  stream.yourdomain.com"
echo ""
echo "Make sure your DNS A record points to this server's IP!"
echo ""

DOMAIN=""
DOMAIN_CONFIRM=""

while [ "$DOMAIN" != "$DOMAIN_CONFIRM" ] || [ -z "$DOMAIN" ]; do
    read -p "Enter domain (e.g., video.yourdomain.com): " DOMAIN
    if [ -z "$DOMAIN" ]; then
        echo "Domain cannot be empty!"
        continue
    fi
    read -p "Confirm domain: " DOMAIN_CONFIRM
    if [ "$DOMAIN" != "$DOMAIN_CONFIRM" ]; then
        echo "Domains do not match! Try again."
        echo ""
    fi
done

echo ""
echo "✓ Domain: $DOMAIN"

# ==========================================
# Step 2: Detect HLS port (standalone vs coexistence)
# ==========================================
echo ""
echo "=========================================="
echo "Step 2: Detecting Port Configuration"
echo "=========================================="

# Read HLS port from docker-compose.yml
if [ -f /opt/mediamtx/docker-compose.yml ]; then
    HLS_HOST_PORT=$(grep -oP '"\K[0-9]+(?=:8888/tcp")' /opt/mediamtx/docker-compose.yml || echo "8888")
else
    HLS_HOST_PORT=8888
fi

echo "✓ Detected HLS host port: $HLS_HOST_PORT"

# Read webeditor port from service file
WEBEDITOR_PORT=$(grep 'WEBEDITOR_PORT=' /etc/systemd/system/mediamtx-webeditor.service 2>/dev/null | cut -d= -f2 || echo "5100")
echo "✓ Detected web editor port: $WEBEDITOR_PORT"

# ==========================================
# Step 3: Install Caddy
# ==========================================
echo ""
echo "=========================================="
echo "Step 3: Caddy Installation"
echo "=========================================="

CADDY_EXISTING=false

if command -v caddy &> /dev/null; then
    CADDY_EXISTING=true
    echo "✓ Caddy is already installed: $(caddy version)"
    if systemctl is-active --quiet caddy; then
        echo "  Caddy is running (serving existing services — will append config)"
    fi
else
    echo "Installing Caddy..."
    apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl > /dev/null 2>&1
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg 2>/dev/null
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null
    apt-get update -qq > /dev/null 2>&1
    apt-get install -y caddy > /dev/null 2>&1
    echo "✓ Caddy installed"
fi

# ==========================================
# Step 4: Firewall
# ==========================================
echo ""
echo "=========================================="
echo "Step 4: Configuring Firewall"
echo "=========================================="

if command -v ufw &> /dev/null; then
    ufw allow 80/tcp  > /dev/null 2>&1
    ufw allow 443/tcp > /dev/null 2>&1
    echo "✓ Ports 80 and 443 opened"
else
    echo "UFW not found — ensure ports 80 and 443 are open"
fi

# ==========================================
# Step 5: Configure Caddyfile
# ==========================================
echo ""
echo "=========================================="
echo "Step 5: Configuring Caddyfile"
echo "=========================================="

MEDIAMTX_CADDY_BLOCK="# MediaMTX Web Editor + HLS — Docker deployment
$DOMAIN {
    # HLS streams — proxy to MediaMTX HLS port
    @hls {
        path *.m3u8 *.ts /hls/*
    }
    handle @hls {
        reverse_proxy localhost:${HLS_HOST_PORT}
    }

    # Web editor
    reverse_proxy localhost:${WEBEDITOR_PORT}
}"

if [ -f /etc/caddy/Caddyfile ]; then
    # Backup existing Caddyfile
    cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.$(date +%Y%m%d_%H%M%S)
    echo "✓ Existing Caddyfile backed up"

    if grep -q "$DOMAIN" /etc/caddy/Caddyfile; then
        echo "WARNING: $DOMAIN already exists in Caddyfile"
        read -p "Replace existing config for this domain? [y/N]: " REPLACE
        if [[ "$REPLACE" =~ ^[Yy]$ ]]; then
            awk -v domain="$DOMAIN" '
                $0 ~ domain " {" { skip=1; next }
                skip && /^}/ { skip=0; next }
                skip { next }
                { print }
            ' /etc/caddy/Caddyfile > /tmp/Caddyfile.tmp
            mv /tmp/Caddyfile.tmp /etc/caddy/Caddyfile
            echo "" >> /etc/caddy/Caddyfile
            echo "$MEDIAMTX_CADDY_BLOCK" >> /etc/caddy/Caddyfile
            echo "✓ Replaced existing config for $DOMAIN"
        else
            echo "Skipping Caddyfile modification."
        fi
    else
        echo "" >> /etc/caddy/Caddyfile
        echo "$MEDIAMTX_CADDY_BLOCK" >> /etc/caddy/Caddyfile
        if [ "$CADDY_EXISTING" = true ]; then
            echo "✓ MediaMTX config appended (existing services preserved)"
        else
            echo "✓ Caddyfile configured"
        fi
    fi
else
    echo "$MEDIAMTX_CADDY_BLOCK" > /etc/caddy/Caddyfile
    echo "✓ New Caddyfile created"
fi

# Validate
echo ""
echo "Validating Caddyfile..."
if caddy validate --config /etc/caddy/Caddyfile 2>/dev/null; then
    echo "✓ Caddyfile is valid"
else
    echo "ERROR: Caddyfile validation failed!"
    echo "Check: caddy validate --config /etc/caddy/Caddyfile"
    echo "Restoring backup..."
    LATEST_BACKUP=$(ls -t /etc/caddy/Caddyfile.backup.* 2>/dev/null | head -1)
    if [ -n "$LATEST_BACKUP" ]; then
        cp "$LATEST_BACKUP" /etc/caddy/Caddyfile
        echo "✓ Backup restored"
    fi
    exit 1
fi

# ==========================================
# Step 6: Start/Reload Caddy
# ==========================================
echo ""
echo "=========================================="
echo "Step 6: Starting Caddy"
echo "=========================================="

systemctl enable caddy > /dev/null 2>&1

if [ "$CADDY_EXISTING" = true ] && systemctl is-active --quiet caddy; then
    systemctl reload caddy
    echo "✓ Caddy reloaded (existing services unaffected)"
else
    systemctl restart caddy
fi

echo "Waiting for Let's Encrypt certificate..."
sleep 15

if systemctl is-active --quiet caddy; then
    echo "✓ Caddy is running"
else
    echo "ERROR: Caddy failed to start"
    echo "Check: journalctl -u caddy -n 50"
    exit 1
fi

# ==========================================
# Step 7: Find Certificate and Update MediaMTX
# ==========================================
echo ""
echo "=========================================="
echo "Step 7: Configuring TLS Certificates"
echo "=========================================="

# Caddy stores certs here
CERT_BASE="/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory"
CERT_DIR="$CERT_BASE/$DOMAIN"
CERT_FILE="$CERT_DIR/$DOMAIN.crt"
KEY_FILE="$CERT_DIR/$DOMAIN.key"

echo "Waiting for certificate (up to 60s)..."
WAIT_COUNT=0
SKIP_CERTS=false

while [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; do
    if [ $WAIT_COUNT -ge 60 ]; then
        echo ""
        echo "WARNING: Certificate not found after 60 seconds."
        echo "Possible causes:"
        echo "  - DNS not pointing to this server yet"
        echo "  - Ports 80/443 not reachable from internet"
        echo "  - Let's Encrypt rate limiting"
        echo ""
        echo "Certificate paths (configure manually later):"
        echo "  Key:  $KEY_FILE"
        echo "  Cert: $CERT_FILE"
        SKIP_CERTS=true
        break
    fi
    sleep 1
    ((WAIT_COUNT++))
done

if [ "$SKIP_CERTS" != "true" ]; then
    echo "✓ Certificate found"

    # Backup mediamtx.yml
    cp /opt/mediamtx/config/mediamtx.yml /opt/mediamtx/config/mediamtx.yml.backup.$(date +%Y%m%d_%H%M%S)
    echo "✓ mediamtx.yml backed up"

    # Update RTSP cert paths
    sed -i '/^rtspServerKey:/{ n; /^  /d }' /opt/mediamtx/config/mediamtx.yml
    sed -i '/^rtspServerCert:/{ n; /^  /d }' /opt/mediamtx/config/mediamtx.yml
    sed -i "s|^rtspServerKey:.*|rtspServerKey: $KEY_FILE|" /opt/mediamtx/config/mediamtx.yml
    sed -i "s|^rtspServerCert:.*|rtspServerCert: $CERT_FILE|" /opt/mediamtx/config/mediamtx.yml

    # Update HLS cert paths
    sed -i '/^hlsServerKey:/{ n; /^  /d }' /opt/mediamtx/config/mediamtx.yml
    sed -i '/^hlsServerCert:/{ n; /^  /d }' /opt/mediamtx/config/mediamtx.yml
    sed -i "s|^hlsServerKey:.*|hlsServerKey: $KEY_FILE|" /opt/mediamtx/config/mediamtx.yml
    sed -i "s|^hlsServerCert:.*|hlsServerCert: $CERT_FILE|" /opt/mediamtx/config/mediamtx.yml

    # Update RTMP cert paths
    sed -i '/^rtmpServerKey:/{ n; /^  /d }' /opt/mediamtx/config/mediamtx.yml
    sed -i '/^rtmpServerCert:/{ n; /^  /d }' /opt/mediamtx/config/mediamtx.yml
    sed -i "s|^rtmpServerKey:.*|rtmpServerKey: $KEY_FILE|" /opt/mediamtx/config/mediamtx.yml
    sed -i "s|^rtmpServerCert:.*|rtmpServerCert: $CERT_FILE|" /opt/mediamtx/config/mediamtx.yml

    # Enable encryption
    sed -i 's/^rtspEncryption: .*/rtspEncryption: "optional"/' /opt/mediamtx/config/mediamtx.yml
    sed -i 's/^hlsEncryption: .*/hlsEncryption: yes/' /opt/mediamtx/config/mediamtx.yml

    echo "✓ Certificate paths written to mediamtx.yml"
    echo "✓ RTSPS encryption enabled (optional mode)"
    echo "✓ HLS encryption enabled"

    # Restart MediaMTX container to pick up config
    echo ""
    echo "Restarting MediaMTX container..."
    docker compose -f /opt/mediamtx/docker-compose.yml restart
    sleep 5

    if docker ps --format '{{.Names}}' | grep -q '^mediamtx$'; then
        echo "✓ MediaMTX container restarted successfully"
    else
        echo "WARNING: MediaMTX container may have issues"
        echo "Check: docker logs mediamtx"
    fi
fi

# ==========================================
# Done
# ==========================================
echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "  Web Editor:  https://$DOMAIN"
echo "  HLS streams: https://$DOMAIN/hls/[streamname]/"
echo ""
echo "  Streaming (direct):"
echo "    RTSP:  rtsp://$DOMAIN:8554/[stream]"
echo "    RTSPS: rtsps://$DOMAIN:8322/[stream]"
echo "    SRT:   srt://$DOMAIN:8890?streamid=[stream]"
echo ""
if [ "$SKIP_CERTS" = "true" ]; then
    echo "  ⚠️  TLS not configured — certificate was not obtained."
    echo "     Fix DNS/firewall then re-run this script."
    echo ""
fi
echo "  Caddy commands:"
echo "    Status:  systemctl status caddy"
echo "    Logs:    journalctl -u caddy -f"
echo "    Reload:  systemctl reload caddy"
echo ""
echo "  MediaMTX commands:"
echo "    Logs:    docker logs mediamtx -f"
echo "    Restart: docker compose -f /opt/mediamtx/docker-compose.yml restart"
echo ""

endscript
