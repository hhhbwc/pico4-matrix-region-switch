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

# 已安装 APK 的 SHA-256 哈希（从之前提取的 APK 计算）
HASH_CN="63fe1f78e1cef07861397c45e1fe7a01eb4d6dd4d2eef6e5f971237636cc78b8"
HASH_GL="1f966e482f9341f05ae7668e58ec6cbb55b71271dd54892df96c0b2ce487a0ee"

log() { echo "[MatrixSwitch] $*"; }

# 获取已安装 APK 路径 (pm path 输出类似 "package:/data/app/.../base.apk")
get_apk_path() {
    pm path "$PKG" 2>/dev/null | grep -o '/data/app/[^:]*/base.apk' | head -1
}

# 检测当前区域: 优先 SHA-256 哈希对比，失败则读缓存
get_current_region() {
    local path apk_hash
    path=$(get_apk_path)
    if [ -n "$path" ]; then
        apk_hash=$(sha256sum "$path" 2>/dev/null | awk '{print $1}')
        case "$apk_hash" in
            "$HASH_CN") echo "cn"; return ;;
            "$HASH_GL") echo "gl"; return ;;
        esac
    fi
    # 哈希检测失败，读缓存
    if [ -f "$STATE_FILE" ]; then
        local cached
        cached=$(grep -o 'region=[^ ]*' "$STATE_FILE" 2>/dev/null | cut -d= -f2)
        case "$cached" in cn|gl) echo "$cached"; return ;; esac
    fi
    echo "unknown"
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

install_matrix() {
    local apk="$1" target="$2"
    local current
    current=$(get_current_region)
    log "Current region: $current, target: $target"

    if [ "$current" = "$target" ]; then
        log "Already on $target region, no change needed."
        return 0
    fi

    local tmp="/data/local/tmp/matrix_$target.apk"
    cp -f "$apk" "$tmp" 2>/dev/null || { log "ERROR: Cannot copy APK"; return 1; }
    chmod 644 "$tmp"

    log "Installing $target Matrix..."
    local out
    out=$(pm install -r -d "$tmp" 2>&1)
    echo "$out" >> /data/local/tmp/matrix_install.log
    if ! echo "$out" | grep -qi "success"; then
        log "ERROR: Install failed: $out"
        return 1
    fi

    # 保存区域缓存
    save_region "$target"
    log "SUCCESS: Switched to $target region"
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
