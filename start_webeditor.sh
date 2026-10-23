#!/bin/bash
set -e
# Wrapper script for MediaMTX web editor
# Re-applies all patches after updates before launching the app

APP="/opt/mediamtx-webeditor/mediamtx_config_editor.py"
OVERLAY="/opt/mediamtx-webeditor/mediamtx_ldap_overlay.py"

echo "[wrapper] Applying patches to $APP..."

# Steps 1-6 run on a copy; the live file is only rewritten if they changed something.
# It is normally chattr +i (so infra-TAK cannot overwrite it), and sed -i always
# rewrites, which fails on an immutable file even when nothing changes.
WORK=$(mktemp)
cp "$APP" "$WORK"

# 1. CONFIG_FILE from env var
sed -i "s|CONFIG_FILE = ['\"].*mediamtx\.yml['\"]|CONFIG_FILE = os.environ.get('MEDIAMTX_CONFIG', '/opt/mediamtx/config/mediamtx.yml')|g" "$WORK"

# 2. BACKUP_DIR from env var
sed -i "s|BACKUP_DIR = ['\"].*['\"]|BACKUP_DIR = os.environ.get('BACKUP_DIR', '/opt/mediamtx/backups')|g" "$WORK"

# 3. Port from env var (hardcoded 5000 → env PORT)
sed -i "s|app\.run(.*port=5000|app.run(host='127.0.0.1', port=int(os.environ.get('PORT', 5100))|g" "$WORK"

# 4. localhost:9997 → 127.0.0.1:9898
sed -i "s|localhost:9997|127.0.0.1:9898|g" "$WORK"
sed -i "s|http://localhost:9997|http://127.0.0.1:9898|g" "$WORK"

# 5. hls_fetch_for_share port 8888 → 8980
sed -i "s|127\.0\.0\.1:8888|127.0.0.1:8980|g" "$WORK"
sed -i "s|localhost:8888|127.0.0.1:8980|g" "$WORK"

# 6. MEDIAMTX_BINARY -> docker exec wrapper
sed -i "s|MEDIAMTX_BINARY = '/usr/local/bin/mediamtx'|MEDIAMTX_BINARY = '/usr/local/bin/mediamtx-docker-wrapper'|g" "$WORK"

if ! cmp -s "$WORK" "$APP"; then
    echo "[wrapper] Steps 1-6 changed the editor; writing it"
    cp "$WORK" "$APP"
fi
rm -f "$WORK"

# 7. Reapply patches/ (byte-compared .orig/.patched fixes -
# see /opt/mediamtx-webeditor/patches/README.md). Must run
# after the sed block above, since its *.orig snapshots were taken post-sed.
echo "[wrapper] Reapplying mediamtx-webeditor-patches..."
/opt/mediamtx-webeditor/patches/apply-patches.sh

# 8. Ensure apply_ldap_overlay is called
if ! grep -q "apply_ldap_overlay" "$APP"; then
    echo "[wrapper] Re-adding apply_ldap_overlay call..."
    sed -i "s|if __name__ == '__main__':|from mediamtx_ldap_overlay import apply_ldap_overlay\napply_ldap_overlay(app)\n\nif __name__ == '__main__':|" "$APP"
fi

echo "[wrapper] Patches applied. Starting web editor..."
exec /usr/bin/python3 "$APP"
