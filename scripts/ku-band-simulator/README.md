# Ku-band link simulator

Simulate a bad satellite-like link between two MediaMTX instances so you can test HLS (and later WebRTC) without flying. The simulator adds delay, jitter, and packet loss to traffic **coming into** the receiver, so the stream looks like it arrived over a bad (e.g. Ku-band) link.

---

## Workflow (how it fits together)

1. **MediaMTX A (source)** — Start a stream here. The **test stream** feature in the config editor is ideal: open the editor on A, use the test stream / play feature so A is publishing a live stream (e.g. on path `teststream`). A is now the “good” source.

2. **MediaMTX B (receiver)** — Add an **external source** that pulls from A:
   - In B’s config editor: External Sources → Add External Source.
   - Point it at A’s stream, e.g.:
     - HLS: `http://A_IP:8888/teststream/index.m3u8`
     - or RTSP: `rtsp://A_IP:8554/teststream`
   - Give it a name (e.g. `test_from_a`). Save. B now pulls from A and rebroadcasts that stream.

3. **Turn on the simulator on B** — On the **receiver** machine (B), run the Ku-band simulator and turn it ON. It impairs **incoming** traffic from A’s IP (delay, jitter, loss). So the stream B receives is degraded, as if it came over Ku.

4. **Test** — Open the stream on B (e.g. B’s watch page or `http://B:8888/test_from_a/index.m3u8`). You see the same content as A’s test stream, but with the impaired link. That’s how you test how HLS (or later WebRTC) behaves on a jittery path without flying.

**Summary:** A = source (test stream), B = receiver (external source from A). Simulator runs **on B** and makes the A→B path bad. You watch the stream on B.

---

## Setup (on the RECEIVER box only)

1. Copy this folder to the receiver server (e.g. `/opt/ku-band-simulator` or run from `scripts/ku-band-simulator`).

2. Copy the config example and set the **source** box’s IP and the receiver’s interface:
   ```bash
   cp ku_band_simulator.conf.example ku_band_simulator.conf
   # Edit ku_band_simulator.conf:
   #   SOURCE_IP = IP of MediaMTX A (the one sending the stream)
   #   INTERFACE = interface on this machine (B) where traffic from A arrives (e.g. eth0)
   ```

3. Make scripts executable:
   ```bash
   chmod +x ku_band_simulator_on.sh ku_band_simulator_off.sh
   ```

4. **Optional — “click a button” UI:** Run the controller as root, then open the page and click On/Off:
   ```bash
   sudo python3 simulator_controller.py
   ```
   Open **http://127.0.0.1:9191** (or http://B_IP:9191 from another machine). Use **Turn simulator ON** / **Turn simulator OFF**.

   **Or** run the scripts by hand:
   ```bash
   sudo ./ku_band_simulator_on.sh
   # ... test your stream on B ...
   sudo ./ku_band_simulator_off.sh
   ```

---

## What it does

- **Where it runs:** On the **receiver** (B). It uses Linux `tc` + `ifb` to shape **incoming** traffic from `SOURCE_IP` (A). So only the A→B path is impaired; A and the rest of the network are unchanged.
- **Default profile:** ~600 ms delay, ±100 ms jitter, 1% packet loss (Ku-like). Override in `ku_band_simulator.conf` with `DELAY_MS`, `JITTER_MS`, `LOSS_PCT` and run the on script again.

## Requirements

- Linux with `tc` and `ifb` (most distros have these).
- Root (sudo) to run the scripts and the controller.

---

## Using the buttons in the External Sources tab

The MediaMTX config editor can run the simulator from the **External Sources** tab (no command line). You still need to set up once on the **receiver** server:

1. **Copy this folder** to the same server as the config editor, e.g. `/opt/mediamtx-webeditor/ku-band-simulator/` (or set `MEDIAMTX_SIMULATOR_DIR` to your path).

2. **Create and edit** `ku_band_simulator.conf` (SOURCE_IP, INTERFACE) as above.

3. **Allow the web editor user to run the scripts with sudo without a password.** For example, if the editor runs as user `mediamtx`:
   ```bash
   sudo visudo
   ```
   Add a line (replace `mediamtx` and the path if different):
   ```
   mediamtx ALL=(ALL) NOPASSWD: /opt/mediamtx-webeditor/ku-band-simulator/ku_band_simulator_on.sh, /opt/mediamtx-webeditor/ku-band-simulator/ku_band_simulator_off.sh
   ```

4. Open the config editor → **External Sources** tab. Use **Turn simulator ON** / **Turn simulator OFF** in the “Ku-band link simulator” panel.
