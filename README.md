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

> **Keep HLS on loopback.** Publish HLS as `127.0.0.1:8980:8888`, not `8980:8888`. Browsers never need MediaMTX's own HLS port: the web editor serves HLS at `/hls-proxy/` (logged-in users), `/shared-hls/` (share links) and `/view-hls/` (open links), and adds the HLS secret itself. Docker's port publishing bypasses ufw, so any port published on `0.0.0.0` is reachable from the internet whatever ufw says.

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

> ⚠️ **Re-running Deploy overwrites the web editor unit.** **Deploy MediaMTX** writes a fresh `/etc/systemd/system/mediamtx-webeditor.service`. That unit starts the editor directly with `python3` (no wrapper), on port `5080`, as user `takwerx`, without `MEDIAMTX_HLS_SECRET`. If you run the editor through the wrapper, restore the unit shown under [Environment variables](#environment-variables) after any redeploy, then run `sudo chmod 600` on it and `sudo systemctl daemon-reload && sudo systemctl restart mediamtx-webeditor`.

### Web editor not loading after an update?

**If you run the editor through the wrapper** (`start_webeditor.sh`, see [Wrapper script](#wrapper-script-start_webeditorsh)), check the wrapper first:

```bash
sudo systemctl status mediamtx-webeditor
sudo journalctl -u mediamtx-webeditor -n 80 --no-pager | grep -E '\[wrapper\]|ok -|FATAL'
```

- **`FATAL - ... matches neither the known original nor the patched version`:** the editor or overlay file changed (a self-update from the Versions tab, a `git pull`, or a hand edit) and no longer matches the patch snapshots. Review the change, update the snapshots (see [Patch snapshots](#patch-snapshots-step-7)) and restart.
- **`[wrapper] Patches applied. Starting web editor...` followed by a Python traceback:** the wrapper finished and the editor itself failed. Read the traceback.
- **No `[wrapper]` lines at all:** the unit isn't running the wrapper, for example after infra-TAK's Deploy rewrote it. See the warning above.

**infra-TAK's Patch web editor button: don't use it on wrapper deployments.** On infra-TAK's own layout (no wrapper), **MediaMTX → Patch web editor** re-downloads the editor, syncs the LDAP overlay and restarts, and that is its fix. On a wrapper deployment it does more harm than good:
- It replaces `mediamtx_config_editor.py` with the upstream copy and switches its port to `5080`.
- It overwrites `mediamtx_ldap_overlay.py` with infra-TAK's bundled copy, which may be older than yours.
- Neither file then matches the snapshots, so the wrapper stops at step 7 and the editor stays down.

If it has already been pressed, restore both files from the snapshots and restart:

```bash
P=/opt/mediamtx-webeditor/patches   # the patch snapshots (see step 7)
W=/opt/mediamtx-webeditor
sudo chattr -i $W/mediamtx_config_editor.py $W/mediamtx_ldap_overlay.py   # if write-protected
sudo cp "$P/mediamtx_config_editor.py.patched" $W/mediamtx_config_editor.py
sudo cp "$P/mediamtx_ldap_overlay.py.patched"  $W/mediamtx_ldap_overlay.py
sudo systemctl restart mediamtx-webeditor
sudo chattr +i $W/mediamtx_config_editor.py $W/mediamtx_ldap_overlay.py
```

**infra-TAK's Deploy MediaMTX button: don't use it on Docker deployments either.** It installs a bare-metal MediaMTX: a native binary, a new `mediamtx.service` that runs it (and then fights the container for the same ports), a new `/usr/local/etc/mediamtx.yml`, a new web editor unit (no wrapper, port `5080`, no HLS secret) and infra-TAK's overlay, and it changes ufw rules.

### Write-protecting the editor

To stop either button, or the editor's own **Versions → Update**, from replacing your files, make them immutable:

```bash
sudo chattr +i /opt/mediamtx-webeditor/mediamtx_config_editor.py /opt/mediamtx-webeditor/mediamtx_ldap_overlay.py \
               /etc/systemd/system/mediamtx-webeditor.service /etc/systemd/system/mediamtx.service
```

- The wrapper still starts normally: its sed steps run on a copy and only write the editor back if something changed (see [Wrapper script](#wrapper-script-start_webeditorsh)).
- Any change you do want needs `sudo chattr -i` first and `sudo chattr +i` after, plus matching snapshot updates.
- Self-updates from the Versions tab stop working, so editor updates become manual: diff the new upstream file against the installed one, re-apply your patches, refresh both snapshots, test, then re-protect.

### After any editor update, check

1. The overlay hook is still in the editor. This should print the `import` line and the `apply_ldap_overlay(app)` call:
   ```bash
   grep -n apply_ldap_overlay /opt/mediamtx-webeditor/mediamtx_config_editor.py
   ```
2. As a non-admin viewer (`vid_public` or `vid_private`), open `/viewer`, click **Watch** on a live stream and confirm it plays. Then create a share link and open it in a private window. Watch and Share use separate code paths and have broken independently before, so test both.

---

## 🔒 Authentik LDAP Overlay

The LDAP overlay (`mediamtx_ldap_overlay.py`) patches the MediaMTX web editor to integrate with [Authentik](https://goauthentik.io) for role-based stream access control. infra-TAK applies it when Authentik is detected, and the wrapper script re-hooks it on every start (see [Wrapper script](#wrapper-script-start_webeditorsh)).

### What it adds

- **Auto-authentication** via Authentik forward auth headers - no separate login page
- **Role-based access** - four Authentik groups mapped to three roles: admin, agency admin and viewer
- **Agency-scoped stream filtering** - users see the streams of the agency in their `agency_abbreviation` attribute
- **Agency admin page** (`/agency-admin`) - lists the agency's streams, with Watch, Share, Stop and a public/private toggle for each
- **Stream Access page** (`/stream-access`) - vid_admin manages users' viewer groups in Authentik
- **No-access page** - logged-in users without a `vid_*` group (or non-admins without an agency) get a page telling them to contact their agency administrator
- **Share links** - no-login token links that expire, with agency and private-stream checks; agency admins can list and revoke their agency's links
- **Open browser links** (`/view/<path>`) - no-login playback of *public* streams, for links sent out from a drone app

### The four groups

| Group | Role | Lands on | Sees | Can do today |
|-------|------|----------|------|--------------|
| `vid_admin` (or `authentik Admins`) | admin | `/` (full editor) | Every agency's streams | Full config editor, Stream Access page, watch any stream, set visibility on any stream (API only, see below) |
| `vid_agency_admin` | agency admin | `/agency-admin` | Own agency's streams, public and private | Watch, share, stop and set public/private visibility on own agency's streams |
| `vid_private` | viewer | `/viewer` | Own agency's public and private streams | Watch, share (including private streams) |
| `vid_public` | viewer | `/viewer` | Own agency's public streams only | Watch, share public streams |
| none of the above | - | No-access page | Nothing | - |

If a user is in more than one group, the highest role wins: admin, then agency admin, then viewer. For example, a member of both `vid_agency_admin` and `vid_private` is an agency admin.

Give each viewer **one** of `vid_public` or `vid_private`: `vid_private` already includes everything `vid_public` sees. There is one private tier per agency, so keep `vid_private` to the people who need sensitive feeds and use share links for anyone else.

### Access Control Model

#### Agency Isolation

One server hosts video for several independent public safety agencies, such as police, sheriff, highway patrol, fire/EMS and a university. Each agency owns its own video. A UAS, body-worn or fixed camera feed can show an active incident, a suspect, a victim or tactical positions, and another agency shouldn't see it just because both agencies share the platform.

So by default, users see only their own agency's streams. Sharing across agencies is a deliberate act, done with a share link. The platform never does it on its own.

- **Gating follows the stream path.** The first part of the path says which agency owns the stream (`MPD` in `MPD/patrol_1`, Mayberry Police Department, example only). A new stream is filtered correctly the moment it's published, with no per-stream setup.
- **The agency comes from the user's `agency_abbreviation` attribute.** TAK Portal sets it when a user is onboarded, so agency membership is managed in one place and the video system never keeps its own list.

#### Role Definitions

- **`vid_admin`: the platform operator.** Runs the server, manages every agency's streams and users, and troubleshoots. It's kept separate from agency admins so that day-to-day agency work never needs server-wide rights.
- **`vid_agency_admin`: the person who runs an agency's streams**, for example a UAS pilot or unit lead. They watch, share, stop and set visibility on their own agency's streams from `/agency-admin`, without access to the config editor or to other agencies. Stop disconnects the stream's publisher. A stream that MediaMTX pulls itself (a configured source) can't be stopped this way, and the page shows an error instead. There is one shared group for every agency, because the agency comes from the user's attribute, not the group. People who run streams only need this group, not a viewer group too.
- **`vid_private`: trusted agency members** who need everything their agency streams, including sensitive feeds.
- **`vid_public`: broader agency members** who should see routine feeds but not ones marked sensitive.

#### Public and Private Streams

Not every feed in an agency is equally sensitive. A traffic or overview camera can go to the whole agency, while a tactical or investigative feed should go to a smaller group.

An agency admin marks each of their own streams public or private, so the decision sits with the agency that owns the video, not with the platform operator.

### Why it's designed this way

- **The old suffix approach is gone.** Earlier versions detected agency admins by TAK Portal groups ending in `-AgencyAdmin`. The overlay now checks only `vid_agency_admin`.
- **Visibility belongs to the stream, not the group.** Each stream is public or private, stored in `stream_visibility.json` in the web editor directory. Streams that aren't listed are public. Agency admins set visibility for their own agency's streams on `/agency-admin`. vid_admin can set it for any stream, but no page has a control for that yet. From a logged-in admin session, `POST /api/stream-visibility` with `{"stream": "MPD/patrol_1", "level": "private"}`, or edit the file directly (it's read on every request):
  ```json
  {
    "MPD/patrol_1": "private"
  }
  ```
  (`MPD` = Mayberry Police Department, example only.)

### How it works, from request to page

1. A user opens `https://video.<your-domain>/`. Caddy's `forward_auth` sends the request to the Authentik outpost (`/outpost.goauthentik.io/auth/caddy`). Users who aren't logged in are sent to the Authentik login.
2. Authentik answers with `X-Authentik-Username` and `X-Authentik-Groups`, with group names separated by `|`. Caddy copies both onto the request it proxies to the web editor on `127.0.0.1:5100`.
3. On every request the overlay splits the groups on `|`, maps them to a role and stores the role in the session. On a user's first request, it also looks the user up in the Authentik API and caches `agency_name` and `agency_abbreviation` in the session. A change to those attributes takes effect when the user starts a new web editor session.
4. If the user is in none of the `vid_*` groups, or isn't an admin and has no `agency_abbreviation`, every page returns the no-access page (HTTP 403). Otherwise, viewers and agency admins can reach only their own pages and APIs. Anything else redirects to `/viewer` or `/agency-admin`. Admins aren't restricted.
5. Stream lists and playback are filtered by agency. The first part of the stream path (`MPD` in `MPD/patrol_1`) is compared with the user's `agency_abbreviation`, ignoring case. Private streams are then hidden from viewers without `vid_private`. Agency admins see their own agency's private streams. A non-admin with no agency sees nothing (earlier versions skipped the filter and showed every agency's streams).

### Setup

1. In Authentik, go to **Directory → Groups** and create `vid_admin`, `vid_agency_admin`, `vid_private` and `vid_public`. Leave **Parent** empty and **Is superuser** off.
2. Check that each user has `agency_name` and `agency_abbreviation` attributes. TAK Portal sets these. Otherwise, set them by hand in the user's **Attributes**:
   ```yaml
   agency_name: Mayberry Police Department   # example only
   agency_abbreviation: MPD
   ```
3. Assign users to groups, for example per agency from your user-management tool (TAK Portal agency templates work, since the `vid_*` groups are visible there; a template saved with "overwrite groups" removes any `vid_*` group it doesn't list). Assign `vid_admin` and `vid_agency_admin` in Authentik directly. The Stream Access page only toggles `vid_private`, `vid_public` and `authentik Admins`. Its Admin toggle adds the user to `authentik Admins`, which also gives them admin rights in Authentik itself.
4. Name streams `AGENCY/streamname` using the agency abbreviation, for example `MPD/patrol_1` (example only). Don't add a `live/` prefix, and use underscores instead of hyphens. Streams whose first path segment isn't an agency abbreviation don't show up for agency users.

### Pages

| Role | URL |
|------|-----|
| vid_admin | `/` (full editor), `/stream-access` |
| vid_agency_admin | `/agency-admin` |
| vid_private / vid_public | `/viewer` |
| anyone with a share link | `/shared/<token>` |
| anyone, public streams only | `/view/<stream path>` |

### Share links

- **Share** always creates a token link that plays without a login, for public and private streams, so it works for people who have no account.
- Viewer and agency-admin links default to 4 hours and can't exceed 24 hours. Admins create theirs through the editor's own UI.
- Viewers and agency admins can only share their own agency's streams, and `vid_public` members can't share private streams.
- Only admins can list every link. Agency admins see and revoke their own agency's links on `/agency-admin`.
- `/api/viewer/hlscred` (which returned the `hlsviewer` password) is no longer allowed for viewers; block it at the proxy as well (see below).

### Open browser links (`/view/`)

For streams pushed from apps that only take one RTMP URL (for example DJI Pilot 2), the matching browser link is the same path under `/view/`:

```
rtmp://video.<your-domain>/MPD/patrol_1   ->   https://video.<your-domain>/view/MPD/patrol_1
```

(`MPD` = Mayberry Police Department, example only.) It plays without a login, but only while the stream is **public**: marking it private turns the link off. `/view-hls/` serves only HLS playlists and media segments, and rejects `.`/`..` path tricks.

### Caddy + Authentik wiring

The video site needs this shape in the Caddyfile. Hostnames are placeholders, and `<authentik-host>` is wherever your Authentik server listens:

```caddy
video.<your-domain> {
    route {
        reverse_proxy /outpost.goauthentik.io/* http://<authentik-host>:9000
        @video_logout path /logout
        redir @video_logout /outpost.goauthentik.io/sign_out?rd=https%3A%2F%2Fvideo.<your-domain>%2F 302

        # Never hand out the hlsviewer password
        respond /api/viewer/hlscred 404

        # Open links for public streams skip Authentik; the web editor refuses private ones.
        # Strip client-sent X-Authentik-* headers: the web editor trusts them.
        @view path /view/* /view-hls/*
        handle @view {
            request_header -X-Authentik-Username
            request_header -X-Authentik-Groups
            request_header -X-Authentik-Email
            reverse_proxy http://127.0.0.1:5100
        }

        # Share links carry their own token, so they skip Authentik
        @shared path /shared/* /shared-hls/*
        handle @shared {
            request_header -X-Authentik-Username
            request_header -X-Authentik-Groups
            request_header -X-Authentik-Email
            reverse_proxy http://127.0.0.1:5100
        }

        handle {
            forward_auth http://<authentik-host>:9000 {
                uri /outpost.goauthentik.io/auth/caddy
                copy_headers X-Authentik-Username X-Authentik-Groups X-Authentik-Email
                trusted_proxies private_ranges
            }
            reverse_proxy http://127.0.0.1:5100
        }
    }
}
```

- `forward_auth` guards everything except the outpost endpoints, the logout redirect, share links and open links. Share links (`/shared/*`, `/shared-hls/*`) skip Authentik because the web editor checks each link's token; open links (`/view/*`, `/view-hls/*`) skip it because the web editor serves only public streams there.
- The web editor trusts the `X-Authentik-*` headers it receives, so port `5100` must be reachable only through Caddy. The wrapper binds it to `127.0.0.1` (step 3), and the routes that skip `forward_auth` strip those headers.
- Don't route anything else straight to MediaMTX. In particular, no `/live/*`-style route that adds the HLS secret: that serves every stream to anyone, with no login and no agency check.
- ⚠️ **`/hls-proxy/*` must never be publicly exposed.** It's a web editor route that fetches HLS from MediaMTX on the user's behalf, using the server's HLS secret. Never add a Caddy route that lets it bypass `forward_auth`.

#### HLS secret

Since MediaMTX v1.18.0, HLS logins use cookie sessions. Instead of handling those cookies, the web editor's `/hls-proxy` sends `Authorization: Bearer <hlsCDNSecret>` to MediaMTX HLS on `127.0.0.1:8980`. `hlsCDNSecret` arrived in MediaMTX v1.18.1, which is why that's the minimum version.

The secret is set in both of these places, and they must match:

| Where | Setting |
|-------|---------|
| `/opt/mediamtx/config/mediamtx.yml` | `hlsCDNSecret: <hls-secret>` |
| web editor systemd unit | `Environment=MEDIAMTX_HLS_SECRET=<hls-secret>` |

Nothing else needs it. Don't add a reverse-proxy route that forwards HLS to MediaMTX with this secret: it would bypass the login and agency checks.

Generate one with `openssl rand -hex 32`. If the two don't match, or the variable is missing, playback through `/watch` fails. Share links keep working, because they use the `hlsviewer` account instead.

### Known issues

- **vid_admin has no visibility control in the UI.** Use the API or edit `stream_visibility.json`, as described above.
- **Open `/view/` links work for anyone who knows the stream path** while the stream is public. Mark sensitive streams private, and send share links rather than `/view/` links when the audience should be limited.
- **Agency abbreviations aren't guaranteed to be unique.** `agency_name` is the unique key, but filtering uses `agency_abbreviation`, so two agencies that share an abbreviation see each other's streams.

---

## ⚙️ Web Editor Service (systemd + wrapper)

systemd runs the editor as `mediamtx-webeditor.service`, through the wrapper script `/opt/mediamtx-webeditor/start_webeditor.sh`. The settings are passed in as `Environment=` lines.

### Environment variables

The unit, with secrets replaced by placeholders:

```ini
[Unit]
Description=MediaMTX Web Configuration Editor
After=network.target

[Service]
Type=simple
ExecStart=/opt/mediamtx-webeditor/start_webeditor.sh
WorkingDirectory=/opt/mediamtx-webeditor
Restart=always
RestartSec=5
User=root
Environment=LDAP_ENABLED=1
Environment=AUTHENTIK_API_URL=http://<authentik-host>:9000
Environment=AUTHENTIK_TOKEN=<authentik-api-token>
Environment=MEDIAMTX_HLS_SECRET=<hls-secret>
Environment=MEDIAMTX_CONFIG=/opt/mediamtx/config/mediamtx.yml
Environment=PORT=5100
Environment=MEDIAMTX_API_URL=http://127.0.0.1:9898
Environment=WEBEDITOR_PORT=5100

[Install]
WantedBy=multi-user.target
```

| Variable | What it does |
|----------|--------------|
| `LDAP_ENABLED` | Read by the overlay hook that infra-TAK injects, which loads the overlay only when this is set. The wrapper's own hook (step 8) loads the overlay either way. |
| `AUTHENTIK_API_URL` | Base URL of the Authentik server. The overlay calls `<url>/api/v3/...`. Defaults to `http://127.0.0.1:9090` if unset. |
| `AUTHENTIK_TOKEN` | Authentik API token. See [Authentik token permissions](#authentik-token-permissions). |
| `MEDIAMTX_HLS_SECRET` | The Bearer secret `/hls-proxy` sends to MediaMTX. It must equal `hlsCDNSecret` in `mediamtx.yml`. See [HLS secret](#hls-secret). |
| `MEDIAMTX_CONFIG` | Path to `mediamtx.yml`. The editor reads and writes the config there (wrapper step 1), and the overlay reads the `hlsviewer` password from it. |
| `PORT` | The port the editor listens on, on `127.0.0.1` only (wrapper step 3, default `5100`). Caddy proxies to it. |
| `MEDIAMTX_API_URL` | The MediaMTX control API the overlay uses to list streams. **Don't put credentials in it** (no `user:pass@`). That once caused a DNS failure for viewer users. MediaMTX's `authInternalUsers` lets the API through without a password from the host instead. |
| `WEBEDITOR_PORT` | Not read by anything. `PORT` is the one that counts. |
| `BACKUP_DIR` | Not set here. Config backups go to `/opt/mediamtx/backups`, the wrapper's default (step 2). |

The unit holds the Authentik token and the HLS secret, so keep it readable only by root:

```bash
sudo chmod 600 /etc/systemd/system/mediamtx-webeditor.service
sudo systemctl daemon-reload && sudo systemctl restart mediamtx-webeditor
```

### Authentik token permissions

These are every Authentik API call the overlay makes:

| API call | Used for |
|----------|----------|
| `GET /api/v3/core/users/?search=<username>` | Read the user's agency attributes at login |
| `GET /api/v3/core/users/?page=…` | List users on the Stream Access page |
| `GET /api/v3/core/groups/?search=<name>` | Find `vid_private`, `vid_public` and `authentik Admins` |
| `POST /api/v3/core/groups/<pk>/add_user/` and `/remove_user/` | Stream Access group toggles |
| `PATCH /api/v3/core/users/<pk>/` | Edit name and email; activate and deactivate users |
| `DELETE /api/v3/core/users/<pk>/` | Delete a user |

The token's user therefore needs to view users and groups, change and delete users, and add and remove group members. It can also add users to `authentik Admins`, so treat it like an admin credential.

### Wrapper script (start_webeditor.sh)

When the web editor updates itself from the Versions tab, the update overwrites the local patches and the overlay hook. systemd runs the wrapper instead of the editor, and the wrapper re-applies everything on every start, including crash restarts (`Restart=always`).

What each step does. Steps 1–6 run on a temporary copy of the editor, which is written back only if they changed something, so the wrapper also works when the editor is write-protected (`chattr +i`):

1. Points `CONFIG_FILE` at `$MEDIAMTX_CONFIG` (default `/opt/mediamtx/config/mediamtx.yml`).
2. Points `BACKUP_DIR` at `$BACKUP_DIR` (default `/opt/mediamtx/backups`).
3. Changes `app.run` from port `5000` to `127.0.0.1:$PORT` (default `5100`). Loopback only, because the editor trusts `X-Authentik-*` headers.
4. Changes the MediaMTX API from `localhost:9997` to `127.0.0.1:9898`.
5. Changes HLS from port `8888` to `127.0.0.1:8980`, the coexistence HLS port.
6. Points `MEDIAMTX_BINARY` at `/usr/local/bin/mediamtx-docker-wrapper`, so the editor's MediaMTX commands run inside the container (`docker exec mediamtx /mediamtx ...`).
7. Runs the patch-snapshot script (see below).
8. Re-adds `from mediamtx_ldap_overlay import apply_ldap_overlay` and `apply_ldap_overlay(app)` before `if __name__ == '__main__':` if they're missing.

Then it `exec`s `python3` on the editor.

The script uses `set -e`. If any step fails, startup stops, so the editor never runs unpatched. systemd retries every 5 seconds, and the error is in the journal.

#### Patch snapshots (step 7)

Step 7 runs `/opt/mediamtx-webeditor/patches/apply-patches.sh`. That directory holds two snapshots each of `mediamtx_config_editor.py` and `mediamtx_ldap_overlay.py`:
- `.orig`: the file as it was after the wrapper's sed steps, before the fixes
- `.patched`: the same file with the fixes applied

On every start the script compares each live file with its snapshots, byte for byte:

| Live file matches | Result |
|-------------------|--------|
| `.patched` | Already patched, nothing to do |
| `.orig` | Copies `.patched` over it |
| neither | Prints `FATAL` and exits. Because of `set -e`, the editor doesn't start |

What this means in practice:
- **Any change to either file must also go into the snapshots.** That includes an editor self-update, a `git pull` of this repo, a hand edit, or even a comment change. Make the same edit in `.orig` and `.patched`, or, once you've reviewed the change, copy the live file over `.patched`. Otherwise the next restart stops at step 7.
- Step 7 has to stay after the sed steps (1–6), because the `.orig` snapshots were taken after them.
- **`patches/` is deployment-specific and not part of this repository** (excluded locally via `.git/info/exclude`), because the snapshots can carry local-only changes. Other installs create their own, or remove step 7 if they don't use these patches.

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

### 🎨 Web Configuration Editor (v2.1.12)
- ✅ **HLS Tuning page** — Segment count, duration, variant, always remux, write queue
- ✅ **HLS presets** — One-click LAN, Internet, and Satellite (KU/KA) profiles
- ✅ **MPEG-TS demux toggle** — Enable/disable from the UI
- ✅ User management with agency/group labels
- ✅ Recording management with retention periods
- ✅ Public access toggle
- ✅ Advanced YAML editor
- ✅ Service control (start/stop/restart)
- ✅ Automatic backups before changes
- ✅ Auto-update from GitHub releases (off when the editor is write-protected; see [Write-protecting the editor](#write-protecting-the-editor))
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
│   └── mediamtx_config_editor.py                  # Web editor application (v2.1.4)
├── scripts/
│   └── ku-band-simulator/                         # Ku-band link simulator
├── mediamtx_ldap_overlay.py                       # Authentik overlay (vid_* roles, agency filtering)
├── start_webeditor.sh                             # systemd wrapper: re-applies patches on every start
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
| 1935 | tcp | RTMP |
| 8890 | udp | SRT (8981 in coexistence mode) |
| 8189 | tcp/udp | WebRTC media (ICE) |
| 80 | tcp | HTTP (Caddy/ACME only) |
| 443 | tcp | HTTPS (Caddy only) |

Keep these off the internet: the API (`127.0.0.1:9898`), HLS (`127.0.0.1:8980`, served through the web editor instead) and WHEP signalling (`127.0.0.1:8887`). RTP/RTCP (`8000`/`8001` udp) only need publishing if `rtspTransports` includes `udp`.

**ufw doesn't protect Docker-published ports.** Docker's NAT rules run before ufw, so publish internal-only ports on `127.0.0.1`, and put any filtering for public container ports in the `DOCKER-USER` chain (for ufw users, a single `*filter` block for `DOCKER-USER` in `/etc/ufw/after.rules`; each `:DOCKER-USER` declaration empties the chain, so don't split it across several blocks).

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
**Web Editor:** overlay tested with v2.1.12 (the copy in `config-editor/` is still v2.1.4)
**Compatible with:** MediaMTX v1.18.1+ (needs `hlsCDNSecret`; tested with v1.21.2)
**Tested on:** Ubuntu 22.04 LTS
