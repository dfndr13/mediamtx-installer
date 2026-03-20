# Web Editor v2.0.4 Release Notes

**Release Date:** March 20, 2026  
**Minimum MediaMTX Version:** v1.17.0

---

## Fixes

### Fixed: YAML corruption from FFmpeg path removal (v2.0.3 bug)

v2.0.3 introduced an automatic removal of the legacy `~^live/(.+)$` FFmpeg re-publish path from `mediamtx.yml`. On standalone (non-infra-TAK) installations where the `runOnReady` value spanned multiple YAML lines, the migration left behind orphaned fragments that corrupted the YAML. This caused the web editor to return 500 errors.

**v2.0.4 fixes this in two ways:**
1. The FFmpeg removal now uses indentation-based block detection, correctly handling multi-line values
2. A cleanup pass removes orphaned `rtsp://localhost:8554/$G1` and `runOnReadyRestart: true` lines left by the v2.0.3 bug

Both run automatically at editor startup. Servers affected by v2.0.3 will self-heal when updated to v2.0.4.

### Other fixes included

- **No-cache headers** — Browser no longer serves stale pages after updates
- **Post-update reload** — Polls service until ready instead of blind 5s delay
- **Backup version labels** — Shows actual versions instead of "unknown"
- **Auto-enable `rtspDemuxMpegts`** — Adds to YAML if missing (from v2.0.3)

---

## If your web editor shows 500 errors (stuck on v2.0.3)

The v2.0.3 YAML corruption prevents the web editor from loading, so you can't use the UI to update. Fix via SSH:

```bash
# One-liner fix — removes orphaned lines and restarts both services
sed -i '/^\s*rtsp:\/\/localhost:8554\/\$G1/d' /usr/local/etc/mediamtx.yml && systemctl restart mediamtx && systemctl restart mediamtx-webeditor
```

After this, the web editor will load again and you can update to v2.0.4 normally.

Alternatively, download v2.0.4 directly (it self-heals on startup):

```bash
curl -sL https://raw.githubusercontent.com/takwerx/mediamtx-installer/main/config-editor/mediamtx_config_editor.py \
  -o /opt/mediamtx-webeditor/mediamtx_config_editor.py && systemctl restart mediamtx-webeditor
```

---

## Full changelog since v2.0.0

- **v2.0.4** — Fix YAML corruption from v2.0.3 FFmpeg removal, no-cache headers, post-update reload polling
- **v2.0.3** — Auto-enable `rtspDemuxMpegts: true` on existing installations
- **v2.0.2** — Auto-remove FFmpeg `/live` path, backup version label fix
- **v2.0.1** — infra-TAK LDAP overlay startup fix, overlay re-sync in `apply_update()`
- **v2.0.0** — Native MPEG-TS demuxing, HLS Tuning page, HLS.js player fixes
