# Pico4 Matrix Region Switch

Pico4 国区/外区 Matrix 一键切换 Magisk 模块。v1.9 起内置 PICO OS 5.2.7–5.13.7 的 8 份完整 `services.jar`，启动时按 `ro.build.display.id` 自动选择对应镜像并 bind 挂载到 `/system/framework/services.jar`；模块不再 magic mount 单个 jar。Matrix APK 仍按需下载，安装前用固定 SHA-256 校验。

## v1.9.2 变更：快速识别区域

- `switch.sh` 不再依赖 `region.prop` 记录，也不再对 90 MB APK 做 SHA-256 来判断区域；改为只读 ZIP 中央目录（`unzip -l`）匹配区域特征文件，整机检测约 150 ms。
  - 国区：`libmetasec_ml`、`account_x_area_code`、`parental_ctrl_known_app_list`
  - 外区：`libmetasec_ov`、`play-services-ads-identifier`、`play-services-basement`
- 优先读 `/data/app`（补丁 Matrix），没有 data 层安装时回退读 `/system`（系统自带 Matrix）。所以**恢复出厂或首次装机、还没装补丁 Matrix 的设备也能直接报出当前区域**，不再是 `unknown`。
- `status` 输出增加两行说明：

```text
Current region: cn
Matrix source: system
Patched Matrix: missing (run switch.sh cn or gl once)
```

- 只有系统自带 Matrix 时，即使目标区域和当前区域相同也会安装补丁 APK（不能因为"区域已经是 cn"就跳过 bootstrap）。
- 两组特征同时命中、或一个都读不到时判定失败，`toggle`/Action 拒绝猜测，显式 `switch.sh cn|gl` 仍可 bootstrap。

## v1.9.1 修复

- 首次装机或恢复出厂后，`/data/app` 里没有补丁 Matrix，`status` 会是 `unknown`；v1.9 连显式 `switch.sh cn|gl` 也会拒绝。现在显式指定目标即可 bootstrap 安装补丁 Matrix，`toggle`/Action 仍会拒绝 unknown，避免瞎猜区域。
- `status` 不再把 `[MatrixSwitch] ERROR...` 日志混进 `Current region:` 结果行（日志统一走 stderr）。
- 新增 adb 可写的手动暂存导入：`adb push Matrix_CN.apk /data/local/tmp/matrix_cn.incoming.apk`，脚本会校验 SHA-256 后自动移入缓存；`matrix_gl.incoming.apk` 同理。

## v1.9 变更

- 支持参考工具覆盖的 13 个 PICO OS 版本（5.2.7–5.13.7），按系统版本自动选择 `services.jar`，不需要在安装时手选。
- `post-fs-data` 用 bind mount 覆盖 `services.jar`；遇到表中没有的系统版本就保持 stock jar，**不会因为挂载了不匹配的框架而开机异常**。
- 5.11.0/5.12.0/5.13.3/5.13.7 共用一份“签名绕过 + `KeySetManagerService` 空指针守卫”的 jar（`2a13a5c4…`），与 `vd_pmsfix` 的框架修复一致。
- 保留 v1.8 的修复：无 power coordinator 时不再空等 30 秒、切换前校验生效 jar、回收 stale lock、切换成功后清理 Matrix 数据、删除临时 APK。

## 支持的系统版本

| PICO OS | services.jar SHA-256（前 12 位） | 说明 |
|---|---|---|
| 5.2.7 | `9bace48f9d41` | 独立 |
| 5.4.0 | `f4c40a4e29d4` | 独立 |
| 5.5.0 | `5ead5cddc9cb` | 独立 |
| 5.6.0 | `2a8870279ce8` | 独立 |
| 5.7.2 | `45f10d60fee5` | 独立 |
| 5.8.2 | `214037d16afb` | 独立 |
| 5.9.2 / 5.9.8 / 5.9.9 | `32463d4fe73b` | 共用一份 |
| 5.11.0 / 5.12.0 / 5.13.3 / 5.13.7 | `2a13a5c401be` | 共用一份，含 KeySet NPE 守卫 |

参考包里没有 5.3.x、5.10.x 和 5.13.7 之后的版本，因此本模块也不支持；遇到这些版本会在安装时明确列出支持范围并中止。

## 工作原理

1. 模块安装时只验证当前系统版本在 `versions.conf` 中，并校验对应 `jars/<sha256>.jar` 的完整性；不会修改 `/system`。
2. 每次开机 `post-fs-data.sh` 读取 `ro.build.display.id`，在 `versions.conf` 中查找匹配的 jar；如果当前生效的 `services.jar` 已经是目标哈希（例如 `vd_pmsfix` 已提供同一份），直接跳过；否则 `chcon u:object_r:system_framework_file:s0` 后 bind mount 到 `/system/framework/services.jar`。重复执行不会叠加挂载。
3. `switch.sh` 在切换前再次核对该 OS 对应的期望哈希与实际生效的 `/system/framework/services.jar`；不一致就拒绝切换。
4. 如果系统版本不在表中（例如 OTA 到了未适配版本），`post-fs-data` 不挂载任何 jar，设备使用 stock `services.jar` 正常启动；`switch.sh` 会报告 unsupported 并拒绝操作。

日志：`/data/local/tmp/matrix_boot.log`（每次开机的 jar 选择/挂载结果）、`/data/local/tmp/matrix_action.log`、`/data/local/tmp/matrix_install.log`。

## 关于 Matrix 自动更新

- 模块安装的 Matrix 是 `9.9.9` / `versionCode 999999999`，这是伪装版本号，正常官方版本（例如系统自带的 `6.1.1` / `600101009`）压不掉它。
- 切换是在 data 层用 `pm install -r -d` 覆盖，**不要替换 `/system/app/Matrix`**；系统自带版本保留为回退。
- 如果 Matrix 被更新器或 OTA 换掉，`switch.sh status` 会按当前 APK 的特征码报告区域并显示 `Matrix source: system`；重新执行 `switch.sh cn|gl` 会重装补丁 APK，不会静默装错包。安装结果仍用固定 SHA-256 校验。
- OTA 到表中已有的新版本时，模块会在下次开机自动切换对应 jar；OTA 到未适配版本时保持 stock，需要补新 jar 后再用。

## 安装与使用

1. 在 Magisk 中从本地安装模块 ZIP，重启。首次开机 `post-fs-data` 会自动挂载当前系统对应的 `services.jar`。
2. 在模块卡片点击 Action 按钮，或运行：

```bash
adb shell su -c "sh /data/adb/modules/pico4_matrix_region_switch/switch.sh status"
adb shell su -c "sh /data/adb/modules/pico4_matrix_region_switch/switch.sh cn"
adb shell su -c "sh /data/adb/modules/pico4_matrix_region_switch/switch.sh gl"
```

首次切换某个区域会下载约 90 MB 的 APK（Google Drive 优先，GitHub Releases 备用），成功后需要重启，再启动 VR 应用。设备被重置或从未装过补丁 Matrix 时，`status` 会显示系统自带 Matrix 的区域和 `Patched Matrix: missing`；先执行 `switch.sh cn` 或 `switch.sh gl` 做一次 bootstrap，之后 Action 按钮即可来回切换。只有特征码完全无法识别时才会返回 `unknown`，此时也仍可显式 bootstrap。

### 手动暂存 / 缓存 APK

推荐用 adb 可写的暂存路径，脚本会校验摘要并移入缓存：

```bash
adb push Matrix_CN.apk /data/local/tmp/matrix_cn.incoming.apk
adb push Matrix_GL.apk /data/local/tmp/matrix_gl.incoming.apk
adb shell su -c "sh /data/adb/modules/pico4_matrix_region_switch/switch.sh cn"
```

也可以直接放入缓存目录，但 `/data/adb` 不是 adb shell 可写目录，需要先 `adb push` 到 `/data/local/tmp`，再用 `su -c "cp ..."`：

```text
/data/adb/pico4_matrix_region_switch/cache/matrix_cn.apk
/data/adb/pico4_matrix_region_switch/cache/matrix_gl.apk
```

### 与 `vd_pmsfix` 共存

`vd_pmsfix` 的 `services.jar` 就是本模块 5.11–5.13 组使用的那份 `2a13a5c4…`（签名绕过 + KeySet NPE 守卫）。5.13.7 上两者字节一致；矩阵模块的 bind mount 会覆盖为同一份文件，不会引入不同补丁。仍不建议再安装第三份不同哈希的 `services.jar` 覆盖模块。

## 文件结构

```text
Pico4_MatrixRegionSwitch/
├── module.prop
├── customize.sh
├── action.sh
├── switch.sh
├── post-fs-data.sh
├── versions.conf
├── jars/<sha256>.jar          # 8 份按 OS 分组的 services.jar
├── webui/index.html
├── system/bin/matrix-download
├── system/etc/pico4-matrix/cacert.pem
└── META-INF/
```

注意：不再包含 `system/framework/services.jar`；jar 由 `post-fs-data.sh` 按当前 OS 选择并 bind 挂载。

## 构建

```bash
7z a -tzip ../Pico4_MatrixRegionSwitch_v1.9.2.zip * .gitattributes
```

## 测试范围与限制

- 8 份 jar 均来自 `P4_OS_527-OS_5110_OR_MAGISK_SU_MATRIX_PATCHER.zip`（该工具每个版本都做过测试；原帖：https://phoenixplace.xyz/showthread.php?tid=3781 ）；我逐份校验了 SHA-256 和 ZIP 完整性。5.13.7 的合并版 jar 在本机完成过 CN→GL 切换、重启和 Matrix 运行验证；其他 OS 版本没有设备可实测，属于“沿用参考工具已验证的镜像 + 同一套挂载逻辑”。
- 本机测试环境为 SELinux **Permissive**（`selinux_permissive` 模块）。Enforcing 下如果 Magisk 域不允许对 `/data` 文件 `chcon` 到 `system_framework_file`，bind 可能被拒绝；日志会写在 `/data/local/tmp/matrix_boot.log`。
- 只支持上表版本；不要在未适配的系统上强行更换 `services.jar`。
- 如果你在某个版本上发现异常，保留 `/data/local/tmp/matrix_boot.log` 和 `matrix_install.log` 再反馈。

## 致谢

- 各版本 `services.jar`、Matrix CN/GL APK 以及版本适配思路来自 PhoenixPlace 论坛的 Matrix Patcher 工具：
  https://phoenixplace.xyz/showthread.php?tid=3781
- `P4_OS_527-OS_5110_OR_MAGISK_SU_MATRIX_PATCHER.zip` 就是该原帖提供的工具包。感谢原作者的逐版本测试与分享；本模块只是把它的 per-OS 镜像接入 Magisk 的启动挂载流程。

## License

MIT
