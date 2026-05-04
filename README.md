# MediaMTX Streaming Server Installer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![MediaMTX](https://img.shields.io/badge/MediaMTX-Auto--Download-blue)](https://github.com/bluenviron/mediamtx)
[![OS Support](https://img.shields.io/badge/OS-Ubuntu%2022.04-green)]()

> ⚠️ **ALPHA — Docker deployment is under active development and has not been tested on a fresh machine. Use at your own risk. Bare-metal install (upstream) is stable.**

**MediaMTX streaming server deployment with HTTPS, RTSPS encryption, and web-based configuration editor. Now with native MPEG-TS demuxing — no FFmpeg required for HLS from ATAK/TAKICU/UAS feeds.**

**Bare-metal install is production-ready. Docker deployment is alpha.**

> **This is a community fork of [takwerx/mediamtx-installer](https://github.com/takwerx/mediamtx-installer) maintained by [dfndr13](https://github.com/dfndr13).**
>
> **What this fork adds:**
> - 🧪 Docker-based MediaMTX deployment (alpha — under active development)
> - 🧪 CloudTAK coexistence mode — automatic port conflict detection and remapping
> - ✅ API port locked to loopback by default (`127.0.0.1`) — never exposed publicly
> - ✅ Custom username/password prompts at install time — no hardcoded or auto-generated credentials
> - ✅ All fixes from upstream v2.0.0–v2.0.4 included

---

## 🚀 Quick Start

### Docker deployment (this fork)

```bash
git clone https://github.com/dfndr13/mediamtx-installer.git
cd mediamtx-installer
chmod +x ubuntu-22.04/*.sh

# Install MediaMTX as a Docker container
sudo ./ubuntu-22.04/Ubuntu_22.04_Install_MediaMTX_Docker.sh
```

The installer will prompt you for:
- API/Web Editor username and password
- HLS Viewer username and password

It will also automatically detect if CloudTAK is running and offer to remap ports to avoid conflicts.

### Bare-metal deployment (original)

```bash
# Install MediaMTX as a systemd service
sudo ./ubuntu-22.04/Ubuntu_22.04_MediaMTX_install.sh

# Install Web Configuration Editor
sudo ./config-editor/Install_MediaMTX_Config_Editor.sh

# (Optional) Add HTTPS
sudo ./ubuntu-22.04/Ubuntu_22.04_Install_MediaMTX_Caddy.sh
```

📖 **[Read the complete deployment guide](MEDIAMTX-DEPLOYMENT-GUIDE.md)**
⚡ **[Quick start for experienced users](MEDIAMTX-QUICK-START.md)**

---

## 🐳 Docker Deployment

### Why Docker?

Running MediaMTX in Docker provides clean isolation, easier updates, and avoids conflicts with other services on the same host — particularly when running alongside CloudTAK, TAK Server, or Authentik.

### CloudTAK Coexistence

CloudTAK ships its own bundled MediaMTX container (`cloudtak-media-1`) which occupies these ports by default:

| Port | Service |
|------|---------|
| `9997/tcp` | CloudTAK media API |
| `8888/tcp` | HLS |
| `8890/tcp` | SRT |

The Docker installer detects CloudTAK automatically and offers **coexistence mode**, which remaps your standalone MediaMTX to non-conflicting ports:

| Port | Standalone | Coexistence |
|------|-----------|-------------|
| HLS | `8888` | `8980` |
| SRT | `8890` | `8981` |
| API | `127.0.0.1:9898` | `127.0.0.1:9898` |

> **Note:** The API is always mapped to host port `9898` (remapped from container-internal `9997`). This is compatible with infra-TAK's MediaMTX web editor, which expects the API on port `9898`.

### Security: API Port is Always Loopback-Only

The MediaMTX control API (`9997` inside the container) is **always mapped to `127.0.0.1` on the host** — never to `0.0.0.0`. This means it is only reachable by processes on the server itself, never from the internet.

This applies to all supporting services. The principle is:

> **Only Caddy faces the internet. Everything else binds to loopback (`127.0.0.1`) or the Docker bridge network.**

If you are running CloudTAK alongside this installer, apply the same fix to `cloudtak-media-1` in your CloudTAK `docker-compose.yml`:

```yaml
# Change this:
- "${MEDIA_PORT_API:-9997}:9997"

# To this:
- "127.0.0.1:${MEDIA_PORT_API:-9997}:9997"
```

Then restart the media container:

```bash
cd ~/CloudTAK && docker compose up -d --no-deps media
```

### Docker File Locations

| File | Path |
|------|------|
| Docker Compose | `/opt/mediamtx/docker-compose.yml` |
| MediaMTX config | `/opt/mediamtx/config/mediamtx.yml` |
| Recordings | `/opt/mediamtx/recordings/` |
| Credentials | `/opt/mediamtx/webeditor.env` , `/opt/mediamtx/mediamtx-credentials.txt` |

### Container Commands

```bash
# View logs
docker logs mediamtx -f

# Restart
docker compose -f /opt/mediamtx/docker-compose.yml restart

# Stop
docker compose -f /opt/mediamtx/docker-compose.yml down

# Update to latest MediaMTX
docker compose -f /opt/mediamtx/docker-compose.yml pull
docker compose -f /opt/mediamtx/docker-compose.yml up -d
```

---

## 🔧 infra-TAK Integration

If you are running [infra-TAK](https://github.com/takwerx/infra-TAK) on the same host, this fork is designed to work alongside it.

### How it works

infra-TAK's MediaMTX marketplace integration expects:
- The MediaMTX API on `127.0.0.1:9898`
- The web editor at `/opt/mediamtx-webeditor/`
- A systemd service named `mediamtx`

This fork maps the Docker container API to `127.0.0.1:9898` by default, satisfying the first requirement. The web editor and systemd service are handled by infra-TAK's own deploy flow when you configure MediaMTX as a **remote SSH target** pointing at `127.0.0.1`.

### Connecting infra-TAK to your Docker instance

1. In infra-TAK, go to **Marketplace → MediaMTX**
2. Set deployment target to **On a remote host (SSH)**
3. Set host to `127.0.0.1`, port `22`, user `takadmin`
4. Click **Generate SSH key**, **Install SSH key**, **Test SSH**, then **Save target settings**
5. Click **Deploy MediaMTX** — infra-TAK will install the web editor and wire it to your Docker container
6. Create a dummy systemd wrapper so infra-TAK's health probe returns `active`:

```bash
sudo tee /etc/systemd/system/mediamtx.service > /dev/null << 'EOF'
[Unit]
Description=MediaMTX (Docker wrapper)

[Service]
Type=oneshot
ExecStart=/bin/true
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable mediamtx
sudo systemctl start mediamtx
```

7. Set `deployed: true` in infra-TAK's settings:

```bash
sudo python3 -c "
import json
p='/opt/infra-tak/.config/settings.json'
s=json.load(open(p))
s['mediamtx_deployment']['deployed']=True
json.dump(s,open(p,'w'),indent=2)
print('done')
"
```

The infra-TAK marketplace will now show MediaMTX as **Installed / Running**.

### Web editor not loading after an update?

The LDAP overlay can become stale after the editor auto-updates. To fix:

1. Open your **infra-TAK console**
2. Go to the **MediaMTX** page
3. Click **Patch web editor**

This re-syncs the LDAP overlay and restarts the editor.

---

## ✨ Features

### 🐳 Docker Install Script (this fork)
- ✅ Deploys MediaMTX as a Docker container
- ✅ Prompts for custom usernames and passwords at install time — no hardcoded credentials
- ✅ Auto-detects CloudTAK and offers port remapping
- ✅ API port always bound to loopback only (`127.0.0.1:9898`)
- ✅ Config and recordings bind-mounted from `/opt/mediamtx/`
- ✅ Installs web editor as systemd service pointed at Docker container
- ✅ Compatible with infra-TAK MediaMTX marketplace integration
- ✅ UFW firewall configuration

### 🔧 MediaMTX Installation Script (bare-metal)
- ✅ Auto-downloads latest MediaMTX from GitHub
- ✅ Ships with proven production YAML configuration
- ✅ **MPEG-TS demuxing enabled by default** — RTSP sources (TAKICU, ATAK UAS, ISR cameras) work with HLS natively
- ✅ No FFmpeg transcoding required for MPEG-TS over RTSP sources
- ✅ Random HLS viewer password generation
- ✅ Unattended-upgrade detection
- ✅ Firewall configuration (UFW)
- ✅ systemd service with auto-start

### 🎨 Web Configuration Editor (v2.0.4)
- ✅ **HLS Tuning page** — Segment count, duration, variant, always remux, write queue
- ✅ **HLS presets** — One-click LAN, Internet, and Satellite (KU/KA) profiles
- ✅ **MPEG-TS demux toggle** — Enable/disable from the UI
- ✅ User management with agency/group labels
- ✅ Recording management with retention periods
- ✅ Public access toggle
- ✅ Advanced YAML editor
- ✅ Service control (start/stop/restart)
- ✅ Automatic backups before changes
- ✅ Auto-update from GitHub releases
- ✅ **Ku-band link simulator** — Impair incoming traffic for HLS testing
- ✅ **Share links** — Token-based share links

### 🔒 Caddy SSL Script
- ✅ Let's Encrypt SSL certificates (automatic)
- ✅ HTTPS reverse proxy for web editor
- ✅ Certificate paths auto-configured for RTSPS/HLS
- ✅ TAK Server Caddy coexistence (appends, doesn't overwrite)

---

## 📋 What You Need

### Required
- Ubuntu 22.04
- 2GB RAM minimum (4GB+ recommended for HLS)
- 2+ CPU cores recommended
- Root/sudo access
- Docker (installed automatically if missing)

### Optional (for SSL/HTTPS)
- Domain name pointed at your server
- Ports 80 and 443 open

---

## 📂 Repository Structure

```
mediamtx-installer/
├── ubuntu-22.04/
│   ├── Ubuntu_22.04_Install_MediaMTX_Docker.sh   # Docker install (this fork)
│   ├── Ubuntu_22.04_MediaMTX_install.sh          # Bare-metal install (original)
│   └── Ubuntu_22.04_Install_MediaMTX_Caddy.sh    # SSL/Let's Encrypt setup
├── config-editor/
│   ├── Install_MediaMTX_Config_Editor.sh          # Web editor installer
│   └── mediamtx_config_editor.py                  # Web editor application (v2.0.4)
├── scripts/
│   └── ku-band-simulator/                         # Ku-band link simulator
├── MEDIAMTX-DEPLOYMENT-GUIDE.md
├── MEDIAMTX-QUICK-START.md
└── README.md
```

---

## 📡 Streaming Protocols

| Protocol | Default Port | Coexistence Port | Use Case |
|----------|-------------|-----------------|---------|
| **RTSP** | 8554/tcp | 8554/tcp | Most apps, VLC, cameras, ATAK |
| **HLS** | 8888/tcp | 8980/tcp | Browser playback |
| **SRT** | 8890/udp | 8981/udp | Low-latency, reliable |
| **RTMP** | 1935/tcp | 1935/tcp | Disabled by default |

### MPEG-TS Demuxing (v2.0.0+)

RTSP sources that wrap H264/AAC inside MPEG-TS (TAKICU, ATAK UAS Tool, ISR cameras) are automatically unwrapped into native tracks. HLS playback works natively — no FFmpeg transcoding required.

---

## 🔐 Security

### API Port — Always Loopback Only

The MediaMTX control API is mapped to `127.0.0.1:9898` on the host in all Docker deployments. It is never reachable from the internet. Only Caddy should bind on `0.0.0.0`.

### Credentials (Docker install)
- The installer prompts for custom usernames and passwords at install time
- No hardcoded or auto-generated credentials — you choose them
- Credentials are saved to `/opt/mediamtx/webeditor.env` and `/opt/mediamtx/mediamtx-credentials.txt`

### Firewall Ports (Docker install)
| Port | Protocol | Purpose |
|------|---------|---------|
| 8554 | tcp | RTSP |
| 8888 | tcp | HLS (8980 in coexistence mode) |
| 8890 | udp | SRT (8981 in coexistence mode) |
| 8000 | udp | RTP |
| 8001 | udp | RTCP |
| 80 | tcp | HTTP (Caddy/ACME only) |
| 443 | tcp | HTTPS (Caddy only) |

The API port (`9898`) is loopback-only — **no firewall rule needed or added.**

---

## 🔀 Fork Relationship

This fork tracks [takwerx/mediamtx-installer](https://github.com/takwerx/mediamtx-installer) upstream. Upstream fixes are merged periodically. Docker-specific additions in this fork are not present in upstream.

If you encounter issues specific to the Docker deployment, open an issue here. For issues with the web editor itself or bare-metal install, check upstream first.

---

## 📚 Documentation

- **[Complete Deployment Guide](MEDIAMTX-DEPLOYMENT-GUIDE.md)**
- **[Quick Start Guide](MEDIAMTX-QUICK-START.md)**
- **[MediaMTX Official Docs](https://github.com/bluenviron/mediamtx)**

---

## 📜 License

MIT License - See [LICENSE](LICENSE) file for details.

---

## 🙏 Credits

- **MediaMTX** by [bluenviron](https://github.com/bluenviron/mediamtx)
- **Original scripts** by [The TAK Syndicate](https://www.thetaksyndicate.org)
- **Docker support & infra-TAK integration** by [dfndr13](https://github.com/dfndr13)

---

**Fork maintained by:** dfndr13
**Upstream:** takwerx/mediamtx-installer
**Web Editor:** v2.0.4
**Compatible with:** MediaMTX v1.17.0+
**Tested on:** Ubuntu 22.04 LTS
