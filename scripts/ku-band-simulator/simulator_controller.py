#!/usr/bin/env python3
"""
Small HTTP server that runs the Ku-band simulator on/off scripts.
Run as root so it can execute the scripts: sudo python3 simulator_controller.py
Then open http://127.0.0.1:9191 and click the button.
"""
import os
import subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ON_SCRIPT = os.path.join(SCRIPT_DIR, "ku_band_simulator_on.sh")
OFF_SCRIPT = os.path.join(SCRIPT_DIR, "ku_band_simulator_off.sh")
PORT = 9191

HTML = """<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Ku-band simulator</title>
  <style>
    body { font-family: sans-serif; max-width: 360px; margin: 2rem auto; padding: 1rem; }
    h1 { font-size: 1.2rem; }
    .btn { display: block; width: 100%; padding: 0.75rem 1rem; margin: 0.5rem 0; font-size: 1rem; cursor: pointer; border: 1px solid #ccc; border-radius: 6px; }
    .btn-on { background: #2e7d32; color: #fff; border-color: #1b5e20; }
    .btn-off { background: #c62828; color: #fff; border-color: #b71c1c; }
    .btn:hover { opacity: 0.9; }
    #msg { margin-top: 1rem; padding: 0.5rem; background: #f5f5f5; border-radius: 4px; font-size: 0.9rem; min-height: 2em; }
    .err { color: #b71c1c; }
  </style>
</head>
<body>
  <h1>Ku-band link simulator</h1>
  <p>Impairs incoming traffic from your source MediaMTX so you can test HLS on a bad link.</p>
  <form method="post" action="/on">
    <button type="submit" class="btn btn-on">Turn simulator ON</button>
  </form>
  <form method="post" action="/off">
    <button type="submit" class="btn btn-off">Turn simulator OFF</button>
  </form>
  <div id="msg"></div>
  <script>
    document.querySelector('form[action="/on"]').addEventListener('submit', function(e) {
      e.preventDefault();
      fetch('/on', { method: 'POST' }).then(r => r.json()).then(d => {
        document.getElementById('msg').textContent = d.msg || d.error || 'Done';
        document.getElementById('msg').className = d.error ? 'err' : '';
      }).catch(() => { document.getElementById('msg').textContent = 'Request failed'; document.getElementById('msg').className = 'err'; });
    });
    document.querySelector('form[action="/off"]').addEventListener('submit', function(e) {
      e.preventDefault();
      fetch('/off', { method: 'POST' }).then(r => r.json()).then(d => {
        document.getElementById('msg').textContent = d.msg || d.error || 'Done';
        document.getElementById('msg').className = d.error ? 'err' : '';
      }).catch(() => { document.getElementById('msg').textContent = 'Request failed'; document.getElementById('msg').className = 'err'; });
    });
  </script>
</body>
</html>
"""


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        print("[simulator]", format % args)

    def do_GET(self):
        if self.path == "/" or self.path == "":
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(HTML.encode())
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path == "/on":
            ok, msg = self._run(ON_SCRIPT)
        elif self.path == "/off":
            ok, msg = self._run(OFF_SCRIPT)
        else:
            self.send_response(404)
            self.end_headers()
            return
        self.send_response(200)
        self.send_header("Content-type", "application/json")
        self.end_headers()
        import json
        body = {"msg": msg} if ok else {"error": msg}
        self.wfile.write(json.dumps(body).encode())

    def _run(self, script):
        if not os.path.isfile(script):
            return False, f"Script not found: {script}"
        try:
            out = subprocess.run(
                ["bash", script],
                capture_output=True,
                text=True,
                timeout=10,
                cwd=SCRIPT_DIR,
            )
            msg = (out.stdout + out.stderr).strip() or ("OK" if out.returncode == 0 else "Failed")
            return out.returncode == 0, msg
        except subprocess.TimeoutExpired:
            return False, "Script timed out"
        except Exception as e:
            return False, str(e)


if __name__ == "__main__":
    print(f"Ku-band simulator controller: http://127.0.0.1:{PORT}")
    print("Run as root (sudo). Click button to turn simulator on/off.")
    HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
