#!/bin/sh
#
# Installs the latest cloudflared-freebsd release on OPNsense.
#
# - downloads the binary and SHA256SUMS from the latest GitHub release
# - verifies the checksum and that the binary runs
# - keeps a backup, swaps the binary atomically and restarts the service
# - waits up to 3 minutes for the tunnel to report ready; if it doesn't,
#   restores the previous binary automatically
#
# Safe to run remotely through the tunnel itself:
#   daemon -f sh /tmp/install-opnsense.sh
#   tail -f /tmp/cloudflared-install.log

set -u

REPO="mateuszszponar/cloudflared-freebsd"
ASSET="cloudflared-freebsd-amd64"
BASE="https://github.com/$REPO/releases/latest/download"
BIN="/usr/local/bin/cloudflared"
TMP="/tmp/cloudflared-download.$$"
READY_URL="${READY_URL:-http://127.0.0.1:2000/ready}"
LOG="/tmp/cloudflared-install.log"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG"; }
fail() { log "ERROR: $*"; rm -f "$TMP" "$TMP.sums"; exit 1; }

# Replace a binary that may be running: copy next to it, then rename (atomic).
swap_in() {
    cp "$1" "$BIN.new" && chmod 755 "$BIN.new" && mv "$BIN.new" "$BIN"
}

[ "$(uname -s)" = "FreeBSD" ] || fail "this script is for FreeBSD/OPNsense"
[ "$(uname -m)" = "amd64" ]   || fail "only amd64 builds are published"
[ -x "$BIN" ]                 || fail "$BIN not found; install os-cloudflared first"

log "Downloading $ASSET from $REPO"
fetch -qo "$TMP"      "$BASE/$ASSET"     || fail "binary download failed"
fetch -qo "$TMP.sums" "$BASE/SHA256SUMS" || fail "checksum download failed"

expected=$(tr -d '\r' < "$TMP.sums" | awk -v f="$ASSET" '$2 == f { print $1 }')
actual=$(sha256 -q "$TMP")
[ -n "$expected" ] && [ "$expected" = "$actual" ] || fail "checksum mismatch (expected '$expected', got '$actual')"
log "Checksum OK: $actual"

chmod 755 "$TMP"
new_version=$("$TMP" --version) || fail "downloaded binary does not run"
old_version=$("$BIN" --version 2>/dev/null)
log "Current: $old_version"
log "New:     $new_version"

cp -p "$BIN" "$BIN.bak" || fail "could not back up $BIN"
log "Backup saved to $BIN.bak"

swap_in "$TMP" || fail "could not replace $BIN"
rm -f "$TMP" "$TMP.sums"
log "Binary replaced, restarting service"
service cloudflared restart >> "$LOG" 2>&1

i=0
while [ "$i" -lt 18 ]; do
    sleep 10
    if fetch -qo /dev/null "$READY_URL" 2>/dev/null; then
        log "OK: tunnel connected, running $("$BIN" --version)"
        exit 0
    fi
    i=$((i + 1))
done

log "Tunnel not ready after 3 minutes, rolling back"
swap_in "$BIN.bak" || { log "ERROR: rollback copy failed"; exit 1; }
service cloudflared restart >> "$LOG" 2>&1
log "Rolled back to $("$BIN" --version)"
exit 1
