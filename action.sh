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

# 用 switch.sh status 检测当前区域（内部用 SHA-256）
CURRENT=$(sh "$SWITCH" status 2>/dev/null | grep '^Current region:' | awk '{print $3}')
echo "CURRENT=$CURRENT" >> "$LOG"

case "$CURRENT" in
    cn) TARGET="gl"; NAME="外区" ;;
    gl) TARGET="cn"; NAME="国区" ;;
    *)  TARGET="cn"; NAME="国区 (默认)" ;;
esac
echo "TARGET=$TARGET" >> "$LOG"

# 执行切换，全部输出捕获到日志
RESULT=$(sh "$SWITCH" "$TARGET" 2>&1)
echo "RESULT=$RESULT" >> "$LOG"

# 输出给 Magisk Manager 通知栏
if echo "$RESULT" | grep -q "SUCCESS"; then
    echo "✅ 切换到 $NAME 成功"
elif echo "$RESULT" | grep -q "Already on"; then
    echo "当前已是 $NAME"
else
    echo "❌ 切换失败，日志: $LOG"
fi

exit 0