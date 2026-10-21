#!/system/bin/sh
# Pico4 Matrix Region Switcher - installer
SKIPMOUNT=false
PROPFILE=false
POSTFSDATA=true
LATESTARTSERVICE=false

ui_print "======================================"
ui_print " Pico4 Matrix Region Switcher v1.9.1"
ui_print "======================================"
MODDIR="$MODPATH"

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

OS=$(getprop ro.build.display.id)
[ -n "$OS" ] || abort "Unable to read ro.build.display.id"
JAR_SHA=$(lookup_jar "$OS") || {
    supported=$(while read -r v h; do
        case "$v" in ''|'#'*) continue ;; esac
        printf '%s ' "$v"
    done < "$MODDIR/versions.conf")
    abort "Unsupported PICO OS: $OS. Supported: $supported"
}

JAR="$MODDIR/jars/$JAR_SHA.jar"
[ -f "$JAR" ] || abort "Bundled services.jar missing for $OS: $JAR"
digest=$(sha256_file "$JAR") || abort "Unable to hash bundled services.jar"
[ "$digest" = "$JAR_SHA" ] || abort "Bundled services.jar digest mismatch: got $digest expected $JAR_SHA"

# v1.9 does not magic-mount services.jar; post-fs-data bind-mounts the matching jar at boot.
rm -f "$MODDIR/system/framework/services.jar"

ui_print "Detected PICO OS: $OS"
ui_print "Selected services.jar: $JAR_SHA"
ui_print "services.jar will be bind-mounted by post-fs-data after reboot"
ui_print "Bundled per-OS jars: 5.2.7 - 5.13.7 (8 unique images)"
ui_print "Matrix CN + GL APKs download on first switch"
ui_print "Google Drive first, GitHub Releases fallback"
ui_print "System-mounted arm64 HTTPS downloader and CA certificate"
ui_print "Cache: /data/adb/pico4_matrix_region_switch/cache"
ui_print "Requires GitHub access, ~250 MB for APKs, ~120 MB module space"
ui_print ""
ui_print "⚡ 切换区域:"
ui_print "  已有补丁 Matrix：打开 Magisk Manager → 模块 → 点 ⚡ 来回切换"
ui_print "  首次/重置后先执行：su -c 'sh /data/adb/modules/pico4_matrix_region_switch/switch.sh cn'（或 gl）"
ui_print "  不想走网络：adb push Matrix_CN.apk /data/local/tmp/matrix_cn.incoming.apk"
ui_print ""
ui_print "📱 查看状态:"
ui_print "  点击模块卡片上的 WebUI 按钮"
ui_print "======================================"
