#!/system/bin/sh
# Pico4 Matrix Region Switcher - installer
SKIPMOUNT=false
PROPFILE=false
POSTFSDATA=true
LATESTARTSERVICE=false

ui_print "======================================"
ui_print " Pico4 Matrix Region Switcher v1.6"
ui_print "======================================"
EXPECTED_FINGERPRINT="Pico/Phoenix/PICOA8110:10/5.13.7/smartcm.1761755159:user/dev-keys"
STOCK_SERVICES_SHA256="bca28757d42e6198a332db77c024c77e2ec66cf1183fbba8a6c47d0e2d7b0125"
PATCHED_SERVICES_SHA256="d41ed85ae0769f7c4f12f568d68ea992ee80f3bef6ac669a1e0b905344af5df9"
SYSTEM_JAR="/system/framework/services.jar"

if [ "$(getprop ro.build.fingerprint)" != "$EXPECTED_FINGERPRINT" ]; then
    abort "Unsupported firmware: $(getprop ro.build.fingerprint)"
fi

sha256_file() {
    local output digest
    output=$(/system/bin/toybox sha256sum -b "$1" 2>/dev/null) || return 1
    set -- $output
    digest="$1"
    [ "${#digest}" -eq 64 ] || return 1
    case "$digest" in *[!0123456789abcdefABCDEF]*) return 1 ;; esac
    echo "$digest"
}

current_sha=$(sha256_file "$SYSTEM_JAR") || abort "Unable to hash services.jar"
case "$current_sha" in
    "$STOCK_SERVICES_SHA256")
        ui_print "Verified original services.jar baseline"
        ;;
    "$PATCHED_SERVICES_SHA256")
        ui_print "Verified existing patched services.jar for module update"
        ;;
    *)
        abort "Unsupported services.jar baseline: $current_sha"
        ;;
esac

ui_print "Installing verified patched services.jar (signature bypass)..."
ui_print "Matrix CN + GL APKs download on first switch"
ui_print "Google Drive first, GitHub Releases fallback"
ui_print "System-mounted arm64 HTTPS downloader and CA certificate"
ui_print "Cache: /data/adb/pico4_matrix_region_switch/cache"
ui_print "Requires GitHub access and about 250 MB free space"
ui_print ""
ui_print "⚡ 切换区域:"
ui_print "  打开 Magisk Manager → 模块"
ui_print "  点击本模块右侧的 ⚡ 按钮"
ui_print "  每次点击：国区 ↔ 外区 来回切换"
ui_print ""
ui_print "📱 查看状态:"
ui_print "  点击模块卡片上的 WebUI 按钮"
ui_print "======================================"