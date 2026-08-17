#!/system/bin/sh
# ==============================================
# Pico4 Matrix Region Switcher - post-fs-data
# 验证 Magisk magic mount 已正确覆盖 services.jar
# 不需要 bind mount 回退，magic mount 在 zygote
# 启动前已完成，比 bind mount 更早更可靠。
# ==============================================

MODDIR=${0%/*}
EXPECTED_FINGERPRINT="Pico/Phoenix/PICOA8110:10/5.13.7/smartcm.1761755159:user/dev-keys"
PATCHED_SERVICES_SHA256="d41ed85ae0769f7c4f12f568d68ea992ee80f3bef6ac669a1e0b905344af5df9"
SYSTEM_JAR="/system/framework/services.jar"
MOD_JAR="$MODDIR/system/framework/services.jar"

if [ -f "$MOD_JAR" ]; then
    fingerprint=$(getprop ro.build.fingerprint)
    module_sha=$(sha256sum "$MOD_JAR" 2>/dev/null | awk '{print $1}')
    current_sha=$(sha256sum "$SYSTEM_JAR" 2>/dev/null | awk '{print $1}')
    if [ "$fingerprint" != "$EXPECTED_FINGERPRINT" ]; then
        echo "[MatrixSwitch] WARNING: unsupported firmware fingerprint: $fingerprint"
    elif [ "$module_sha" != "$PATCHED_SERVICES_SHA256" ]; then
        echo "[MatrixSwitch] WARNING: module services.jar digest mismatch: $module_sha"
    elif [ "$current_sha" = "$PATCHED_SERVICES_SHA256" ]; then
        echo "[MatrixSwitch] services.jar patched via verified magic mount"
    else
        echo "[MatrixSwitch] WARNING: services.jar mismatch (expected $PATCHED_SERVICES_SHA256, got $current_sha)"
        echo "[MatrixSwitch] Module may need reinstall or re-enable"
    fi
fi

exit 0