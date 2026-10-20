#!/system/bin/sh
# Pico4 Matrix Region Switcher - post-fs-data
# Selects the services.jar matching the running PICO OS and bind-mounts it.
# If the OS is not in versions.conf, the stock services.jar is left untouched.

MODDIR=${0%/*}
[ "$MODDIR" = "." ] && MODDIR=$(pwd)
case "$MODDIR" in .|"") MODDIR=/data/adb/modules/pico4_matrix_region_switch ;; esac

LOG=/data/local/tmp/matrix_boot.log
SYSTEM_JAR=/system/framework/services.jar

log() { echo "[MatrixSwitch] $*" >> "$LOG"; }

sha256_file() {
    local output digest
    output=$(/system/bin/toybox sha256sum -b "$1" 2>/dev/null) || return 1
    set -- $output
    digest="$1"
    [ "${#digest}" -eq 64 ] || return 1
    case "$digest" in *[!0123456789abcdefABCDEF]*) return 1 ;; esac
    echo "$digest"
}

lookup_jar() {
    local v h
    while read -r v h; do
        case "$v" in ''|'#'*) continue ;; esac
        [ "$v" = "$1" ] && { echo "$h"; return 0; }
    done < "$MODDIR/versions.conf"
    return 1
}

mkdir -p /data/local/tmp
echo "=== $(date) ===" > "$LOG"

OS=$(getprop ro.build.display.id)
JAR_SHA=$(lookup_jar "$OS") || {
    log "unsupported PICO OS: $OS; leaving stock services.jar"
    exit 0
}
SRC="$MODDIR/jars/$JAR_SHA.jar"
[ -f "$SRC" ] || {
    log "ERROR: missing jar for $OS: $SRC"
    exit 0
}

current=$(sha256_file "$SYSTEM_JAR" 2>/dev/null) || current=
if [ "$current" = "$JAR_SHA" ]; then
    log "services.jar already matches $OS ($JAR_SHA); no bind needed"
    exit 0
fi

chown 0:0 "$SRC" 2>/dev/null
chmod 644 "$SRC" 2>/dev/null
chcon u:object_r:system_framework_file:s0 "$SRC" 2>/dev/null || log "WARNING: chcon failed"

if ! mount --bind "$SRC" "$SYSTEM_JAR"; then
    log "ERROR: bind mount failed for $OS ($JAR_SHA)"
    exit 0
fi
log "bound services.jar for $OS ($JAR_SHA)"

digest=$(sha256_file "$SYSTEM_JAR")
if [ "$digest" = "$JAR_SHA" ]; then
    log "verified effective services.jar $digest"
else
    log "ERROR: effective services.jar $digest expected $JAR_SHA"
fi
exit 0
