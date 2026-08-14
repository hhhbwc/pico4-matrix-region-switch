#!/system/bin/sh
# ==============================================
# Pico4 Matrix Region Switcher - Action Button
# Magisk Manager 模块上的 ⚡ 按钮
# 点击一次：国区↔外区来回切换
# ==============================================

export PATH=/system/bin:/system/xbin:/sbin:/vendor/bin:/system/sbin:$PATH

MODDIR=/data/adb/modules/pico4_matrix_region_switch
SWITCH="$MODDIR/switch.sh"
LOG="/data/local/tmp/matrix_action.log"

echo "=== Matrix Action $(date) ===" > "$LOG"
echo "pwd=$(pwd)" >> "$LOG"

# Let switch.sh detect and toggle the region itself. Parsing its display-oriented
# status output here caused an unknown value to fall through to CN every time.
RESULT=$(sh "$SWITCH" toggle 2>&1)
echo "RESULT=$RESULT" >> "$LOG"

# 输出给 Magisk Manager 通知栏
if echo "$RESULT" | grep -q "SUCCESS: Switched to gl"; then
    echo "✅ 切换到外区成功"
elif echo "$RESULT" | grep -q "SUCCESS: Switched to cn"; then
    echo "✅ 切换到国区成功"
elif echo "$RESULT" | grep -q "Already on"; then
    echo "当前已经是目标区域"
else
    echo "❌ 切换失败（不会默认切到国区），日志: $LOG"
fi

exit 0
