# Pico4 Matrix Region Switch

Pico4 国区/外区 Matrix 一键切换的 Magisk 模块。

## 背景

Pico4 的 Matrix（应用商店/系统桌面）分国区（CN）和外区（Global）两个版本，不同版本对应不同地区的服务生态。但系统限制同一版本号只能装一个，手动切换需要卸载重装、找 APK、打补丁，非常麻烦。

这个模块让你：
- **💡 一键切换**：在 Magisk Manager 里点 ⚡ 按钮，国区↔外区来回切
- **🔓 签名绕过**：内置 patched `services.jar`，突破 Pico 的签名验证限制
- **📦 自带 APK**：模块内置国区/外区两版 Matrix，无需手动下载

## 原理

### 三层结构

```
┌─────────────────────────────────────────────────────────┐
│  Magisk Manager (用户界面)                              │
│  ⚡ 按钮 → action.sh → switch.sh cn/gl                  │
│  WebUI  → index.html (状态查看)                         │
├─────────────────────────────────────────────────────────┤
│  Magisk Magic Mount (开机自动)                          │
│  /data/adb/modules/.../system/framework/services.jar    │
│          ↓ mount --bind (透明覆盖)                       │
│  /system/framework/services.jar (签名绕过补丁)          │
├─────────────────────────────────────────────────────────┤
│  switch.sh (核心切换逻辑)                                │
│  1. SHA-256 检测已安装 APK 确定当前区域                  │
│  2. pm install -r -d 安装另一个区的 APK                 │
│  3. 更新 region.prop 缓存                               │
└─────────────────────────────────────────────────────────┘
```

### 签名绕过

Pico 系统在 `services.jar` 中实现了签名校验（`IPackageManagerSmtExBase`），安装 Matrix 时会检查签名是否与系统预置一致。patcher 工具的 `services.jar` 补丁修改了 `IExtPackageManagerService.skipSigningCheck()` 方法，使其放行特定公钥哈希的 APK。

模块内置的 `services.jar` 对应 Pico OS 5.13.7，其他版本请自行从 patcher 工具提取对应版本。

### 区域检测

`switch.sh status` 通过比较已安装 Matrix APK 的 SHA-256 哈希来判断当前处于哪个区域：

| 哈希值 | 区域 |
|--------|------|
| `63fe1f78e1cef07861397c45e1fe7a01eb4d6dd4d2eef6e5f971237636cc78b8` | 国区 |
| `1f966e482f9341f05ae7668e58ec6cbb55b71271dd54892df96c0b2ce487a0ee` | 外区 |

## 使用方法

### 前置条件
- Pico4 已 root（Magisk）
- 系统版本 **5.13.7**（其他版本需自行替换 services.jar）

### 安装
1. 下载 Releases 页面的 zip
2. Magisk Manager → 模块 → 从本地安装
3. 重启

### 切换区域
- **⚡ 一键切换**：Magisk Manager → 模块 → 点模块卡片的 ⚡ 按钮
- 每次点击：国区 ↔ 外区 来回切换

### 手动切换
```bash
adb shell su -c "sh /data/adb/modules/pico4_matrix_region_switch/switch.sh status"
adb shell su -c "sh /data/adb/modules/pico4_matrix_region_switch/switch.sh cn"
adb shell su -c "sh /data/adb/modules/pico4_matrix_region_switch/switch.sh gl"
```

## 文件结构

```
Pico4_MatrixRegionSwitch/
├── module.prop              # 模块元信息
├── customize.sh             # 安装脚本
├── action.sh                # ⚡ 按钮（来回切换）
├── switch.sh                # 核心切换脚本
├── post-fs-data.sh          # 开机校验
├── region.prop              # 区域缓存
├── webui/
│   └── index.html           # WebUI 状态页
└── system/
    ├── framework/
    │   └── services.jar     # 签名绕过补丁 (5.13.7)
    └── etc/matrix/
        ├── Matrix_CN.apk    # 国区 9.9.9
        └── Matrix_GL.apk    # 外区 9.9.9
```

## 构建

```bash
# 打包模块
cd Pico4_MatrixRegionSwitch
zip -r ../Pico4_Matrix_Region_Switcher.zip * -x "common/*"
```

## 致谢

- [P4_OS_527-OS_5110_OR_MAGISK_SU_MATRIX_PATCHER](https://github.com/) - 原始 patcher 工具，提供 services.jar 补丁和 APK
- Magisk 开源社区

## License

MIT