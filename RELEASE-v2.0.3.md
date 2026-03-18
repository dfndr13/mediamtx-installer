# Web Editor v2.0.3 Release Notes

**Release Date:** March 18, 2026  
**Minimum MediaMTX Version:** v1.17.0

---

## Changes

### Auto-enable MPEG-TS demuxing on existing installations

On startup, the web editor now checks `mediamtx.yml` for `rtspDemuxMpegts` and adds it under `pathDefaults` if missing:

```yaml
pathDefaults:
  rtspDemuxMpegts: true
```

Without this, RTSP sources wrapping H264 inside MPEG-TS (TAKICU, ATAK UAS Tool, ISR cameras) appear as `1 track (MPEG-TS)` and HLS playback fails with "the stream doesn't contain any supported codec." With the flag enabled, MediaMTX v1.17.0+ unwraps the container into native `H264 + KLV` tracks automatically.

New installations already had this in the default YAML. This migration brings existing installations up to the same baseline.

---

## Full changelog since v2.0.0

- **v2.0.3** — Auto-enable `rtspDemuxMpegts: true` on existing installations
- **v2.0.2** — Auto-remove FFmpeg `/live` path, post-update reload polling, backup version label fix
- **v2.0.1** — infra-TAK LDAP overlay startup fix, overlay re-sync in `apply_update()`
- **v2.0.0** — Native MPEG-TS demuxing, HLS Tuning page, HLS.js player fixes, `rtspDemuxMpegts` toggle
