#!/system/bin/sh
# ==============================================
# Pico4 Matrix Region Switcher - post-fs-data
# 验证 Magisk magic mount 已正确覆盖 services.jar
# 不需要 bind mount 回退，magic mount 在 zygote
# 启动前已完成，比 bind mount 更早更可靠。
# ==============================================

MODDIR=${0%/*}
PATCHED_MD5="641c73778ca417e8551a3b8355b93777"
SYSTEM_JAR="/system/framework/services.jar"
MOD_JAR="$MODDIR/system/framework/services.jar"

if [ -f "$MOD_JAR" ]; then
    CURRENT_MD5=$(md5sum "$SYSTEM_JAR" 2>/dev/null | awk '{print $1}')
    if [ "$CURRENT_MD5" = "$PATCHED_MD5" ]; then
        echo "[MatrixSwitch] services.jar already patched via magic mount"
    else
        echo "[MatrixSwitch] WARNING: services.jar mismatch (expected $PATCHED_MD5, got $CURRENT_MD5)"
        echo "[MatrixSwitch] Module may need reinstall or re-enable"
    fi
fi

exit 0