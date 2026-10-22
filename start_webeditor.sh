#!/bin/bash
set -e
# Wrapper script for MediaMTX web editor
# Re-applies all patches after updates before launching the app

APP="/opt/mediamtx-webeditor/mediamtx_config_editor.py"
OVERLAY="/opt/mediamtx-webeditor/mediamtx_ldap_overlay.py"

echo "[wrapper] Applying patches to $APP..."

# 1. CONFIG_FILE from env var
sed -i "s|CONFIG_FILE = ['\"].*mediamtx\.yml['\"]|CONFIG_FILE = os.environ.get('MEDIAMTX_CONFIG', '/opt/mediamtx/config/mediamtx.yml')|g" "$APP"

# 2. BACKUP_DIR from env var
sed -i "s|BACKUP_DIR = ['\"].*['\"]|BACKUP_DIR = os.environ.get('BACKUP_DIR', '/opt/mediamtx/backups')|g" "$APP"

# 3. Port from env var (hardcoded 5000 → env PORT)
sed -i "s|app\.run(.*port=5000|app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 5100))|g" "$APP"

# 4. localhost:9997 → 127.0.0.1:9898
sed -i "s|localhost:9997|127.0.0.1:9898|g" "$APP"
sed -i "s|http://localhost:9997|http://127.0.0.1:9898|g" "$APP"

# 5. hls_fetch_for_share port 8888 → 8980
sed -i "s|127\.0\.0\.1:8888|127.0.0.1:8980|g" "$APP"
sed -i "s|localhost:8888|127.0.0.1:8980|g" "$APP"

# 6. MEDIAMTX_BINARY -> docker exec wrapper
sed -i "s|MEDIAMTX_BINARY = '/usr/local/bin/mediamtx'|MEDIAMTX_BINARY = '/usr/local/bin/mediamtx-docker-wrapper'|g" "$APP"

# 7. Reapply mediamtx-webeditor-patches (byte-compared .orig/.patched fixes -
# see /home/takadmin/CloudTAK/mediamtx-webeditor-patches/README.md). Must run
# after the sed block above, since its *.orig snapshots were taken post-sed.
echo "[wrapper] Reapplying mediamtx-webeditor-patches..."
/home/takadmin/CloudTAK/mediamtx-webeditor-patches/apply-patches.sh

# 8. Ensure apply_ldap_overlay is called
if ! grep -q "apply_ldap_overlay" "$APP"; then
    echo "[wrapper] Re-adding apply_ldap_overlay call..."
    sed -i "s|if __name__ == '__main__':|from mediamtx_ldap_overlay import apply_ldap_overlay\napply_ldap_overlay(app)\n\nif __name__ == '__main__':|" "$APP"
fi

echo "[wrapper] Patches applied. Starting web editor..."
exec /usr/bin/python3 "$APP"
