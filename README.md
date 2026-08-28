# Pico4 Matrix Region Switch

Pico4 国区/外区 Matrix 一键切换 Magisk 模块。模块不再内置两个大型 APK；首次切换目标区域时从 GitHub Releases 下载，并在安装前用固定 SHA-256 校验。

## 功能与限制

- Magisk Manager 的 Action 按钮执行 CN/Global 来回切换。
- `services.jar` 签名绕过补丁仍内置，**只支持 Pico OS 5.13.7 的指定 fingerprint**。
- Matrix APK 按需下载到 `/data/adb/pico4_matrix_region_switch/cache`，已验证的缓存会复用。
- 下载失败、GitHub Release 不可访问、哈希不匹配或 APK 不是已知版本时，脚本会拒绝安装。
- 设备必须能访问 GitHub，并有至少约 250 MB 可用空间（下载、临时文件和安装期间会同时占用空间）。模块自带 arm64 HTTPS 下载器和 CA 证书，PICO 4 的 arm64 设备无需另行安装 `curl` 或 `wget`。
- 切换期间会设置 `pico_matrix_coord_state=transitioning`；如果 V-Sleep 正在运行，脚本会先请求它恢复显示/CPU 快照，等待进入 `idle` 后才继续。切换完成后需要重启。

## 下载源与完整性校验

| 区域 | GitHub Release 资产 | 期望 SHA-256 |
|---|---|---|
| CN | [Matrix_CN.apk](https://github.com/hhhbwc/pico4-matrix-region-switch/releases/download/v1.0/Matrix_CN.apk) | `63fe1f78e1cef07861397c45e1fe7a01eb4d6dd4d2eef6e5f971237636cc78b8` |
| Global | [Matrix_GL.apk](https://github.com/hhhbwc/pico4-matrix-region-switch/releases/download/v1.0/Matrix_GL.apk) | `1f966e482f9341f05ae7668e58ec6cbb55b71271dd54892df96c0b2ce487a0ee` |

Release 资产是静态 APK 文件；脚本使用 HTTPS 跟随重定向并在安装前校验 SHA-256。

## 使用方法

### 前置条件

- Pico4 已 root，并安装 Magisk。
- 系统 fingerprint 必须是：
  `Pico/Phoenix/PICOA8110:10/5.13.7/smartcm.1761755159:user/dev-keys`
- 模块内 `services.jar` 必须在重启后通过 Magic Mount 生效。
- 系统至少有一个已安装且哈希匹配的 CN/Global Matrix APK；未知版本不会被自动猜测。
- 模块内置适用于 `arm64-v8a` 的 HTTPS 下载器；其他架构设备必须手动把经过校验的文件放入缓存目录，命名为 `matrix_cn.apk` 或 `matrix_gl.apk`。

### 安装与切换

1. 下载模块 ZIP，在 Magisk 中从本地安装并重启。
2. 在模块卡片点击 Action 按钮，或运行：

```bash
adb shell su -c "sh /data/adb/modules/pico4_matrix_region_switch/switch.sh status"
adb shell su -c "sh /data/adb/modules/pico4_matrix_region_switch/switch.sh cn"
adb shell su -c "sh /data/adb/modules/pico4_matrix_region_switch/switch.sh gl"
```

首次切换某个区域会下载约 90 MB 的 APK。成功后需要重启设备，再启动 VR 应用。日志位置：

- `/data/local/tmp/matrix_action.log`
- `/data/local/tmp/matrix_install.log`

### 手动缓存与恢复

将已验证的 APK 放入以下路径即可跳过下载：

```text
/data/adb/pico4_matrix_region_switch/cache/matrix_cn.apk
/data/adb/pico4_matrix_region_switch/cache/matrix_gl.apk
```

脚本每次使用缓存前都会重新计算 SHA-256。下载中断产生的 `.part` 文件会被清理；可以删除整个 `cache` 目录后重试。不要修改脚本中的哈希值来绕过校验。

## 文件结构

```text
Pico4_MatrixRegionSwitch/
├── module.prop
├── customize.sh
├── action.sh
├── switch.sh
├── post-fs-data.sh
├── region.prop
├── webui/index.html
├── bin/matrix-download
├── bin/cacert.pem
└── system/framework/services.jar
```

## 构建

```bash
7z a -tzip ../Pico4_MatrixRegionSwitch_v1.3.zip *
```

构建包包含脚本、WebUI、元数据、arm64 HTTPS 下载器、CA 证书和 `services.jar`，不包含两个大型 Matrix APK。

## License

MIT
