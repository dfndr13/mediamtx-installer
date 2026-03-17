# Web Editor v1.1.9 — Release notes

**Release date:** March 2026

## Highlights

- **HLS playback tuning** — Updated all HLS.js player instances to stay further from the live edge (`liveSyncDurationCount: 5`), keep played segments in memory (`liveBackBufferLength: 30`), and prevent HLS.js from treating live streams as VOD (`liveDurationInfinity: true`). Addresses segment overrun issues observed on satellite feeds where the HLS muxer restarts due to upstream SRT decode errors.
- **Satellite SRT preset** — Increased default latency from 2000 ms to 4000 ms, matching values tested on live KU-band ISR feeds. Applies to new external sources created with the Satellite (KU/KA Band) profile.
- **Install script defaults** — Updated `hlsSegmentDuration` from 500 ms to 3 s, `hlsSegmentCount` from 3 to 7, `hlsAlwaysRemux` to yes, and `writeQueueSize` from 512 to 1024. These match the production-tested values for satellite feed rebroadcast.

---

## HLS playback changes

All five HLS.js player instances (Active Streams popup, authenticated stream player, recording player, shared stream page, watch page) now use:

| Setting | v1.1.8 | v1.1.9 | Why |
|---------|--------|--------|-----|
| `liveSyncDurationCount` | 4 | **5** | Stay 5 segments (~15 s) behind live edge; 2-segment cushion before hitting unavailable segments |
| `liveBackBufferLength` | _(not set)_ | **30** | Keep 30 s of played segments in memory to avoid re-fetching on seek-back |
| `liveDurationInfinity` | _(not set)_ | **true** | Prevents HLS.js from treating a live stream as VOD and trying to "catch up" |
| `liveMaxLatencyDurationCount` | 7 | 7 | Unchanged — max drift before resync equals full playlist depth |
| `maxBufferLength` | 30 | 30 | Unchanged |
| `maxMaxBufferLength` | 60 | 60 | Unchanged |

---

## Satellite SRT preset

| Parameter | v1.1.8 | v1.1.9 |
|-----------|--------|--------|
| `latency` | 2000 ms | **4000 ms** |
| `peerlatency` | 2000 ms | **4000 ms** |
| `rcvlatency` | 2000 ms | **4000 ms** |
| `lossmaxttl` | 30 | 30 |
| `payloadsize` | 1316 | 1316 |

Existing external sources are not affected — the preset only applies when creating new sources or editing existing ones with the Satellite profile selected.

---

## Install script changes

These affect new installations only. Existing deployments should update `mediamtx.yml` manually if needed.

| Setting | v1.1.8 | v1.1.9 | Why |
|---------|--------|--------|-----|
| `hlsSegmentDuration` | 500 ms | **3 s** | 500 ms segments are too aggressive; browser can't fetch fast enough on impaired links |
| `hlsSegmentCount` | 3 | **7** | Matches `liveMaxLatencyDurationCount` in the player; gives 21 s playlist depth |
| `hlsAlwaysRemux` | no | **yes** | Pre-generates HLS segments so first viewer doesn't wait |
| `writeQueueSize` | 512 | **1024** | Higher throughput for concurrent streams |

---

## Known issue: SRT decode errors on satellite feeds

MediaMTX v1.16.3 logs `unexpected sequence number: X, expected 0` (~30/sec) on SRT sources over KU-band satellite. This causes the HLS muxer to fail every 10–15 seconds with `unable to extract DTS: too many reordered frames (12)`, restarting the muxer and creating segment discontinuities. This is an upstream issue in MediaMTX's MPEG-TS demuxer / datarhei/gosrt library, not a configuration problem. The HLS.js tuning in this release mitigates playback impact but does not eliminate the root cause.

---

## Version

- **Web Editor:** v1.1.9
- **Compatible with:** MediaMTX v1.16.3; Ubuntu 22.04 LTS.
