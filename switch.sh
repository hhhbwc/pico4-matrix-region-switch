#!/system/bin/sh
# ==============================================
# Pico4 Matrix Region Switcher - switch.sh
# 用法:
#   sh switch.sh status   - 显示当前区域
#   sh switch.sh toggle   - 在国区和外区之间切换
#   sh switch.sh cn       - 切换到国区
#   sh switch.sh gl       - 切换到外区
# ==============================================

export PATH=/system/bin:/system/xbin:/sbin:/vendor/bin:/system/sbin:$PATH

MODDIR=${0%/*}
# 若从 Magisk action 环境执行 ($0=./action.sh, 工作目录=模块目录)
[ "$MODDIR" = "." ] && MODDIR=$(pwd)
# 硬编码兜底
case "$MODDIR" in
    .|"") MODDIR=/data/adb/modules/pico4_matrix_region_switch ;;
esac

MATRIX_CN="$MODDIR/system/etc/matrix/Matrix_CN.apk"
MATRIX_GL="$MODDIR/system/etc/matrix/Matrix_GL.apk"
if [ ! -f "$MATRIX_CN" ] || [ ! -f "$MATRIX_GL" ]; then
    for base in /data/adb/modules/pico4_matrix_region_switch /data/adb/modules_update/pico4_matrix_region_switch; do
        if [ -f "$base/system/etc/matrix/Matrix_CN.apk" ]; then
            MODDIR="$base"
            MATRIX_CN="$base/system/etc/matrix/Matrix_CN.apk"
            MATRIX_GL="$base/system/etc/matrix/Matrix_GL.apk"
            break
        fi
    done
fi

PKG="com.bytedance.pico.matrix"
STATE_FILE="$MODDIR/region.prop"
COORD_DIR="/data/adb/pico4-coord"
MATRIX_LOCK="$COORD_DIR/matrix-switch.lock"
PAPER_SUPPRESS="$COORD_DIR/paper-autostart.suppress"
EXPECTED_FINGERPRINT="Pico/Phoenix/PICOA8110:10/5.13.7/smartcm.1761755159:user/dev-keys"

# 已安装 APK 的 SHA-256 哈希（从之前提取的 APK 计算）
HASH_CN="63fe1f78e1cef07861397c45e1fe7a01eb4d6dd4d2eef6e5f971237636cc78b8"
HASH_GL="1f966e482f9341f05ae7668e58ec6cbb55b71271dd54892df96c0b2ce487a0ee"

log() { echo "[MatrixSwitch] $*"; }

# 获取已安装 APK 路径 (pm path 输出类似 "package:/data/app/.../base.apk")
get_apk_path() {
    pm path "$PKG" 2>/dev/null | grep -o '/data/app/[^:]*/base.apk' | head -1
}

sha256_file() {
    local path output digest
    path="$1"
    [ -f "$path" ] || return 1
    output=$(/system/bin/toybox sha256sum -b "$path" 2>/dev/null) || return 1
    set -- $output
    digest="$1"
    [ "${#digest}" -eq 64 ] || return 1
    case "$digest" in
        *[!0123456789abcdefABCDEF]*) return 1 ;;
    esac
    echo "$digest"
}

get_current_region() {
    local path apk_hash
    path=$(get_apk_path)
    [ -n "$path" ] || { log "ERROR: Matrix APK path unavailable"; echo "unknown"; return; }
    apk_hash=$(sha256_file "$path") || {
        log "ERROR: cannot hash installed Matrix APK"
        echo "unknown"
        return
    }
    case "$apk_hash" in
        "$HASH_CN") echo "cn" ;;
        "$HASH_GL") echo "gl" ;;
        *)
            log "ERROR: unknown installed Matrix APK digest: $apk_hash"
            echo "unknown"
            ;;
    esac
}

save_region() {
    echo "region=$1" > "$STATE_FILE"
}

require_root() {
    if [ "$(id -u)" != "0" ]; then
        log "ERROR: 需要 root, 请用 su 运行"
        exit 1
    fi
}

require_compatible_firmware() {
    local fingerprint
    fingerprint=$(getprop ro.build.fingerprint)
    if [ "$fingerprint" != "$EXPECTED_FINGERPRINT" ]; then
        log "ERROR: unsupported firmware fingerprint: $fingerprint"
        return 1
    fi
    return 0
}

begin_transition() {
    mkdir -p "$COORD_DIR" || return 1
    if [ -e "$MATRIX_LOCK" ]; then
        log "ERROR: another Matrix transition is already active"
        return 1
    fi
    if [ -e "$PAPER_SUPPRESS" ]; then
        log "ERROR: Paper maintenance session is active"
        return 1
    fi
    if [ "$(settings get global pico_power_coord_sleep_active 2>/dev/null)" = "1" ]; then
        log "ERROR: V-Sleep display transaction is active"
        return 1
    fi
    echo "pid=$$ started=$(date +%s)" > "$MATRIX_LOCK" || return 1
    return 0
}

end_transition() {
    rm -f "$MATRIX_LOCK"
}

install_matrix() {
    local apk="$1" target="$2"
    local current payload_hash installed_path installed_hash
    require_compatible_firmware || return 1
    [ -f "$apk" ] || { log "ERROR: target Matrix payload is missing: $apk"; return 1; }
    case "$target" in
        cn) payload_hash="$HASH_CN" ;;
        gl) payload_hash="$HASH_GL" ;;
        *) log "ERROR: invalid target region: $target"; return 1 ;;
    esac
    installed_hash=$(sha256_file "$apk") || {
        log "ERROR: cannot hash target Matrix payload: $apk"
        return 1
    }
    if [ "$installed_hash" != "$payload_hash" ]; then
        log "ERROR: target payload digest mismatch: got $installed_hash expected $payload_hash"
        return 1
    fi
    begin_transition || return 1
    current=$(get_current_region)
    log "Current region: $current, target: $target"
    case "$current" in
        cn|gl) ;;
        *)
            log "ERROR: refusing to install with unknown current region"
            end_transition
            return 1
            ;;
    esac

    if [ "$current" = "$target" ]; then
        log "Already on $target region, no change needed."
        end_transition
        return 0
    fi

    local tmp="/data/local/tmp/matrix_$target.apk"
    cp -f "$apk" "$tmp" 2>/dev/null || { log "ERROR: Cannot copy APK"; end_transition; return 1; }
    chmod 644 "$tmp"

    log "Installing $target Matrix..."
    local out
    out=$(pm install -r -d "$tmp" 2>&1)
    echo "$out" >> /data/local/tmp/matrix_install.log
    if ! echo "$out" | grep -qi "success"; then
        log "ERROR: Install failed: $out"
        end_transition
        return 1
    fi

    installed_path=$(get_apk_path)
    installed_hash=$(sha256_file "$installed_path") || {
        log "ERROR: cannot verify installed Matrix APK"
        end_transition
        return 1
    }
    if [ "$installed_hash" != "$payload_hash" ]; then
        log "ERROR: installed APK digest mismatch: got $installed_hash expected $payload_hash"
        end_transition
        return 1
    fi

    save_region "$target"
    settings put global pico_matrix_coord_generation "$(date +%s)" 2>/dev/null
    settings put global pico_matrix_coord_state "reboot-required" 2>/dev/null
    end_transition
    log "SUCCESS: Switched to $target region; verified digest $installed_hash; reboot required before VR use"
    return 0
}

toggle_region() {
    local current target
    current=$(get_current_region)
    case "$current" in
        cn) target="gl" ;;
        gl) target="cn" ;;
        *)
            log "ERROR: Cannot determine current region; refusing to default to CN"
            return 1
            ;;
    esac

    log "Toggling $current -> $target"
    if [ "$target" = "cn" ]; then
        install_matrix "$MATRIX_CN" "$target"
    else
        install_matrix "$MATRIX_GL" "$target"
    fi
}

# ==== MAIN ====
case "$1" in
    status)
        echo "Current region: $(get_current_region)"
        ;;
    toggle)
        require_root
        toggle_region
        ;;
    cn)
        require_root
        install_matrix "$MATRIX_CN" "cn"
        ;;
    gl)
        require_root
        install_matrix "$MATRIX_GL" "gl"
        ;;
    *)
        echo "Usage: sh $0 {status|toggle|cn|gl}"
        exit 1
        ;;
esac
exit $?
