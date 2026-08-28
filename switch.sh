#!/system/bin/sh
# Pico4 Matrix Region Switcher
# Usage: sh switch.sh {status|toggle|cn|gl}

export PATH=/system/bin:/system/xbin:/sbin:/vendor/bin:/system/sbin:$PATH

MODDIR=${0%/*}
[ "$MODDIR" = "." ] && MODDIR=$(pwd)
case "$MODDIR" in .|"") MODDIR=/data/adb/modules/pico4_matrix_region_switch ;; esac

PKG="com.bytedance.pico.matrix"
STATE_FILE="$MODDIR/region.prop"
COORD_DIR="/data/adb/pico4-coord"
MATRIX_LOCK="$COORD_DIR/matrix-switch.lock"
PAPER_SUPPRESS="$COORD_DIR/paper-autostart.suppress"
MATRIX_INTENT="$COORD_DIR/matrix-switch.intent"
CACHE_DIR="/data/adb/pico4_matrix_region_switch/cache"
HANDOFF_TIMEOUT=30
EXPECTED_FINGERPRINT="Pico/Phoenix/PICOA8110:10/5.13.7/smartcm.1761755159:user/dev-keys"

URL_CN="https://github.com/hhhbwc/pico4-matrix-region-switch/releases/download/v1.0/Matrix_CN.apk"
URL_GL="https://github.com/hhhbwc/pico4-matrix-region-switch/releases/download/v1.0/Matrix_GL.apk"
HASH_CN="63fe1f78e1cef07861397c45e1fe7a01eb4d6dd4d2eef6e5f971237636cc78b8"
HASH_GL="1f966e482f9341f05ae7668e58ec6cbb55b71271dd54892df96c0b2ce487a0ee"

log() { echo "[MatrixSwitch] $*"; }

sha256_file() {
    local path output digest
    path="$1"
    [ -f "$path" ] || return 1
    output=$(/system/bin/toybox sha256sum -b "$path" 2>/dev/null) || return 1
    set -- $output
    digest="$1"
    [ "${#digest}" -eq 64 ] || return 1
    case "$digest" in *[!0123456789abcdefABCDEF]*) return 1 ;; esac
    echo "$digest"
}

get_apk_path() {
    pm path "$PKG" 2>/dev/null | grep -o '/data/app/[^:]*/base.apk' | head -1
}

get_current_region() {
    local path apk_hash
    path=$(get_apk_path)
    [ -n "$path" ] || { log "ERROR: Matrix APK path unavailable"; echo unknown; return; }
    apk_hash=$(sha256_file "$path") || { log "ERROR: cannot hash installed Matrix APK"; echo unknown; return; }
    case "$apk_hash" in
        "$HASH_CN") echo cn ;;
        "$HASH_GL") echo gl ;;
        *) log "ERROR: unknown installed Matrix APK digest: $apk_hash"; echo unknown ;;
    esac
}

require_root() {
    [ "$(id -u)" = 0 ] || { log "ERROR: 需要 root, 请用 su 运行"; return 1; }
}

require_compatible_firmware() {
    local fingerprint
    fingerprint=$(getprop ro.build.fingerprint)
    [ "$fingerprint" = "$EXPECTED_FINGERPRINT" ] && return 0
    log "ERROR: unsupported firmware fingerprint: $fingerprint"
    return 1
}

begin_transition() {
    mkdir -p "$COORD_DIR" || return 1
    if [ -e "$MATRIX_LOCK" ]; then log "ERROR: another Matrix transition is already active"; return 1; fi
    if [ -e "$PAPER_SUPPRESS" ]; then log "ERROR: Paper maintenance session is active"; return 1; fi
    (set -C; : > "$MATRIX_LOCK") 2>/dev/null || { log "ERROR: cannot acquire transition lock"; return 1; }
    printf 'pid=%s started=%s\n' "$$" "$(date +%s)" > "$MATRIX_LOCK"
}

request_power_handoff() {
    local token request phase active snapshot ack started
    phase=$(settings get global pico_power_coord_v2_phase 2>/dev/null)
    active=$(settings get global pico_power_coord_sleep_active 2>/dev/null)
    snapshot=$(settings get global pico_power_coord_snapshot_valid 2>/dev/null)
    case "$phase:$active:$snapshot" in
        idle:0:0|:0:0) return 0 ;;
    esac
    token="matrix-$(date +%s)-$$"
    request="2|$token|power|matrix-switch"
    settings put global pico_power_coord_v2_request "$request" 2>/dev/null || { log "ERROR: cannot request V-Sleep handoff"; return 1; }
    log "Requested V-Sleep restoration before Matrix switch"
    started=$(date +%s)
    while :; do
        phase=$(settings get global pico_power_coord_v2_phase 2>/dev/null)
        active=$(settings get global pico_power_coord_sleep_active 2>/dev/null)
        snapshot=$(settings get global pico_power_coord_snapshot_valid 2>/dev/null)
        ack=$(settings get global pico_power_coord_v2_ack 2>/dev/null)
        if [ "$ack" = "$request" ] && [ "$phase" = idle ] && [ "$active" != 1 ] && [ "$snapshot" != 1 ]; then
            log "V-Sleep restoration acknowledged"
            return 0
        fi
        if [ "$phase" = error ]; then log "ERROR: V-Sleep restoration entered error state"; return 1; fi
        [ $(( $(date +%s) - started )) -ge "$HANDOFF_TIMEOUT" ] && { log "ERROR: timed out waiting for V-Sleep restoration"; return 1; }
        sleep 1
    done
}

end_transition() { rm -f "$MATRIX_LOCK"; }

region_values() {
    case "$1" in
        cn) REGION_HASH="$HASH_CN"; REGION_NAME=CN ;;
        gl) REGION_HASH="$HASH_GL"; REGION_NAME=GL ;;
        *) return 1 ;;
    esac
}

run_download() {
    local url out rc
    url="$1"
    out="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 2 --connect-timeout 20 --max-time 1800 -o "$out" "$url" 2>&1
        return $?
    fi
    if command -v wget >/dev/null 2>&1; then
        wget -O "$out" "$url" 2>&1
        return $?
    fi
    if command -v busybox >/dev/null 2>&1 && busybox wget --help >/dev/null 2>&1; then
        busybox wget -O "$out" "$url" 2>&1
        return $?
    fi
    if toybox wget --help >/dev/null 2>&1; then
        toybox wget -O "$out" "$url" 2>&1
        return $?
    fi
    log "ERROR: no curl/wget downloader available; install one or place a verified APK in $CACHE_DIR"
    return 127
}

ensure_cached() {
    local target cache part url digest
    target="$1"
    region_values "$target" || return 1
    case "$target" in cn) url="$URL_CN" ;; gl) url="$URL_GL" ;; esac
    cache="$CACHE_DIR/matrix_${target}.apk"
    part="$cache.part"
    mkdir -p "$CACHE_DIR" || { log "ERROR: cannot create cache directory: $CACHE_DIR"; return 1; }

    digest=$(sha256_file "$cache" 2>/dev/null)
    if [ "$digest" = "$REGION_HASH" ]; then
        log "Using verified cached $REGION_NAME Matrix APK"
        CACHED_APK="$cache"
        return 0
    fi
    [ -e "$cache" ] && rm -f "$cache"
    rm -f "$part"

    log "Downloading $REGION_NAME Matrix APK from GitHub Releases"
    if ! run_download "$url" "$part"; then
        rm -f "$part"
        log "ERROR: download failed; check GitHub access or install curl/wget"
        return 1
    fi
    digest=$(sha256_file "$part" 2>/dev/null)
    if [ "$digest" != "$REGION_HASH" ]; then
        rm -f "$part"
        log "ERROR: downloaded $REGION_NAME APK hash mismatch: got ${digest:-unreadable}, expected $REGION_HASH"
        log "The GitHub asset may be unavailable, incomplete, or a different APK build"
        return 1
    fi
    mv -f "$part" "$cache" || { rm -f "$part"; log "ERROR: cannot commit APK cache"; return 1; }
    CACHED_APK="$cache"
    log "Downloaded and verified $REGION_NAME Matrix APK"
}

install_matrix() {
    local target current payload_hash installed_path installed_hash tmp out
    target="$2"
    region_values "$target" || { log "ERROR: invalid target region: $target"; return 1; }
    current=$(get_current_region)
    log "Current region: $current, target: $target"
    case "$current" in cn|gl) ;; *) log "ERROR: refusing to install with unknown current region"; return 1 ;; esac
    [ "$current" = "$target" ] && { log "Already on $target region, no change needed."; return 0; }

    require_compatible_firmware || return 1
    begin_transition || return 1
    trap 'if [ "$(settings get global pico_matrix_coord_state 2>/dev/null)" = transitioning ]; then settings put global pico_matrix_coord_state idle 2>/dev/null; fi; end_transition; rm -f "$MATRIX_INTENT"' 0 1 2 3 15
    printf 'pid=%s target=%s started=%s\n' "$$" "$target" "$(date +%s)" > "$MATRIX_INTENT"
    settings put global pico_matrix_coord_state transitioning 2>/dev/null
    request_power_handoff || return 1
    ensure_cached "$target" || return 1
    payload_hash="$REGION_HASH"
    tmp="/data/local/tmp/matrix_${target}.apk"
    cp -f "$CACHED_APK" "$tmp" 2>/dev/null || { log "ERROR: cannot copy APK to $tmp"; return 1; }
    chmod 644 "$tmp"
    log "Installing $target Matrix..."
    out=$(pm install -r -d "$tmp" 2>&1)
    printf '%s\n' "$out" >> /data/local/tmp/matrix_install.log
    if ! printf '%s\n' "$out" | grep -qi success; then log "ERROR: Install failed: $out"; return 1; fi

    installed_path=$(get_apk_path)
    installed_hash=$(sha256_file "$installed_path") || { log "ERROR: cannot verify installed Matrix APK"; return 1; }
    [ "$installed_hash" = "$payload_hash" ] || { log "ERROR: installed APK digest mismatch: got $installed_hash expected $payload_hash"; return 1; }
    echo "region=$target" > "$STATE_FILE"
    settings put global pico_matrix_coord_generation "$(date +%s)" 2>/dev/null
    settings put global pico_matrix_coord_state reboot-required 2>/dev/null
    log "SUCCESS: Switched to $target region; verified digest $installed_hash; reboot required before VR use"
}

toggle_region() {
    local current target
    current=$(get_current_region)
    case "$current" in cn) target=gl ;; gl) target=cn ;; *) log "ERROR: Cannot determine current region; refusing to default to CN"; return 1 ;; esac
    install_matrix "$MATRIX_UNUSED" "$target"
}

case "$1" in
    status) echo "Current region: $(get_current_region)" ;;
    toggle) require_root && toggle_region ;;
    cn|gl) require_root && install_matrix '' "$1" ;;
    *) echo "Usage: sh $0 {status|toggle|cn|gl}"; exit 1 ;;
esac
exit $?
