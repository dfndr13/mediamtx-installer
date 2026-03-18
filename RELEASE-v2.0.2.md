# Web Editor v2.0.2 Release Notes

**Release Date:** March 18, 2026  
**Minimum MediaMTX Version:** v1.17.0

---

## Changes

### Auto-remove legacy FFmpeg `/live` re-publish path

On startup, the web editor now checks `mediamtx.yml` for the legacy `~^live/(.+)$` FFmpeg re-publish path and removes it automatically. With `rtspDemuxMpegts` enabled (MediaMTX v1.17.0+), MPEG-TS sources are unwrapped natively and the FFmpeg copy step is no longer needed.

- Runs once at editor startup — if the path isn't there, nothing happens
- MediaMTX auto-reloads the config after the file is modified
- No manual YAML editing required

### Post-update page reload fix

After clicking "Apply Update," the page now polls the server until the service is back up before reloading, instead of using a fixed 5-second delay that often reloaded before the service was ready. Users now see a live countdown ("Service is restarting... 3s... 4s...") and the page reloads automatically once the editor responds.

### Backup version labels fix

The Version Management page now correctly shows version numbers (e.g., "v2.0.0", "v1.1.8") for previous backup files instead of "unknown." The bug was caused by Python's file read-ahead buffering returning unreliable byte positions, which caused the version extraction loop to exit before reaching the `CURRENT_VERSION` line.

---

## Upgrade path

| Current Version | What happens |
|---|---|
| **v2.0.1** | Auto-update pulls v2.0.2. FFmpeg `/live` path removed on first startup. |
| **v2.0.0** | Auto-update pulls v2.0.2. Overlay re-sync runs, FFmpeg path removed on startup. |
| **v1.1.9 or earlier** | Auto-update pulls v2.0.2. Editor starts overlay-safe, FFmpeg path removed. infra-TAK users may need one "Patch web editor" for the initial transition. |

---

## Full changelog since v2.0.0

- **v2.0.2** — Auto-remove FFmpeg `/live` path, post-update reload polling, backup version label fix
- **v2.0.1** — infra-TAK LDAP overlay startup fix, overlay re-sync in `apply_update()`
- **v2.0.0** — Native MPEG-TS demuxing, HLS Tuning page, HLS.js player fixes, `rtspDemuxMpegts` toggle
