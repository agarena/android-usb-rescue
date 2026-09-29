---
name: android-usb-rescue
disable-model-invocation: true
description: 安卓手机 USB 救援：电源键损坏/失灵、手机黑屏点不亮、卡在 fastboot 界面退不出时，用一根数据线+电脑完成屏幕点亮、安全重启回系统、相册定位与照片导出，并生成双击即用的"软件电源键"脚本。当用户提到手机开不了机、点不亮、唤醒屏幕、电源键坏了、按键失灵、卡 fastboot、退出 fastboot、手机救砖、adb unauthorized/未授权、fastboot 驱动装不上、手机相册在哪、导出照片时使用——即使用户没提"救援"二字。覆盖小米/红米、华为、荣耀、OPPO、一加、真我、vivo、三星、Pixel 等品牌；Windows 全流程，附 Linux/macOS/WSL 差异。
---

# 安卓手机 USB 救援（无电源键操作）

目标：手机电源键失灵（损坏/进水/按键坏）或系统卡死时，只靠一根 USB 数据线和电脑完成三件事：

1. **点亮/熄灭屏幕**——软件替代电源键
2. **从 fastboot 卡死状态重启回系统**
3. **定位并导出相册照片**

安全总原则：**只读优先**。对手机执行 fastboot 命令时，只允许 `devices` / `getvar` / `reboot`；`flash` / `erase` / `format` / `oem` / `unlock` 一律禁止——会把本可救回的手机变砖。

## 第 0 步：检测手机状态（决定走哪条路）

需要电脑装有 Android platform-tools（`adb` / `fastboot` 命令）。运行检测脚本：

```
powershell -ExecutionPolicy Bypass -File <skill目录>\scripts\detect-phone.ps1
```

按结果分流：

| 检测结果 | 含义 | 去向 |
|---|---|---|
| adb 显示 `device` | 已授权，完全可控 | 直接去第 3 步 |
| adb 显示 `unauthorized` | 系统在跑，等手机上点授权确认 | 第 1 步 |
| fastboot 列出序列号 | 手机停在 fastboot 界面 | 第 2 步 |
| 只有便携设备（MTP），无 adb | 系统正常，adb 接口未上线 | 第 4 步 + 品牌备注 |
| 全部为空 | 线材/接口/USB调试设置问题 | 换线换口，查开发者选项 |

**unauthorized 的铁律**：此状态下电脑发不出任何命令（包括远程唤醒屏幕）。授权必须在手机屏幕上人工点「允许」，这是安卓的安全机制，没有软件绕过。所以先把屏幕物理点亮（第 1 步）。

## 第 1 步：不用电源键点亮屏幕

以下手势按命中概率从高到低试（均为手指操作，不用按键）：

1. **双击屏幕**——多数国产机和三星支持双击亮屏；
2. **拔插 USB 线**——插上瞬间大概率亮充电动画/时钟，那个画面足够操作；
3. **按音量键**——部分机型音量键可唤醒；
4. **指纹**——背面指纹：触摸即亮屏+解锁一步到位；屏下指纹需先亮屏；侧面指纹通常就是电源键本体（已坏），跳过；
5. **抬手亮屏**——拿起手机轻晃。

屏幕亮了之后：

- 看到「允许 USB 调试吗？」弹窗：勾选「一律允许」→ 点「允许」。锁屏上看不到弹窗时，先解锁（指纹/密码均可），再拔插一次数据线，弹窗会重新出现；
- 屏幕快熄时反复用上述手势即可。授权成功后**立刻**做第 3 步的常亮设置，摆脱对亮屏手势的依赖。

## 第 2 步：卡在 fastboot 的救援（无需电源键）

fastboot 是引导层界面，手机在等电脑指令，反而是最可控的状态。

- **Linux / macOS**：`fastboot devices` 能看到序列号 → `fastboot reboot`，完成。
- **Windows**：最常见的坑是 `fastboot devices` 为空——这是驱动问题，不是手机问题。修复三步：①诊断问题码 → ②用 Zadig 装 WinUSB 驱动 → ③修正设备接口 GUID（fastboot 只认 Google 驱动的 GUID，通用 WinUSB 驱动装完后必须改这一步，否则永远"看不见"设备）。
  **完整步骤、下载地址与踩坑清单 → 读 `references/windows-fastboot-driver.md`**，修复脚本在 `scripts/fix-fastboot-guid.ps1`。
- **兜底**：电池耗尽后插电充电，多数机型会自动开机（耗时数小时，最后手段）。

提示：三星没有标准 fastboot（其下载模式走 Odin 协议，`fastboot` 看不到），救援方式不同，见 `references/vendor-notes.md`。

## 第 3 步：软件电源键（adb 授权成功后立刻做）

先设置"插线常亮"，再记住两条键值，最后给用户生成双击脚本：

```bash
adb shell svc power stayon usb     # 插着 USB 期间屏幕常亮不锁屏（核心！）
adb shell input keyevent 224       # 点亮屏幕（KEYCODE_WAKEUP）
adb shell input keyevent 26        # 熄屏并锁屏（KEYCODE_POWER 短按）
```

生成桌面双击脚本（唤醒手机.bat / 熄屏锁屏.bat）：

```
powershell -ExecutionPolicy Bypass -File <skill目录>\scripts\make-power-scripts.ps1
```

**品牌坑**：`input keyevent` 属于模拟输入，部分品牌要求额外开关，失败（SecurityException/注入被拒）时：
- 小米 MIUI：开发者选项 → 打开「USB调试（安全设置）」（需插 SIM 卡并登录小米账号）；
- 其余品牌见 `references/vendor-notes.md`。

## 第 4 步：相册定位与导出

手机用「传输文件（MTP）」模式连接后，Windows 资源管理器直接可见：**此电脑 → <机型名> → 内部存储设备**。回答"相册在哪"按此表：

| 内容 | 路径（内部存储下） |
|---|---|
| 相机照片/视频 | `DCIM/Camera` |
| 截图 | `DCIM/Screenshots`（部分机型在 `Pictures/Screenshots`） |
| 录屏 | `DCIM/ScreenRecorder` 或 `Movies` |
| 微信图片 | `Pictures/WeiXin` |
| QQ 图片 | `Pictures/QQ`、`Pictures/QQImage` |
| 抖音/微博等 App 保存图 | `Pictures/<应用名>` |

全量扫描各相册文件数（哪些目录占空间一目了然）：

```
powershell -ExecutionPolicy Bypass -File <skill目录>\scripts\scan-photos.ps1
```

批量导出（adb 授权后）：

```bash
adb pull /sdcard/DCIM/Camera D:\photos\
```

## 常见排查

- **adb 列表突然变空**：手机端「USB 用途」要选「传输文件」——部分品牌"仅充电"会隐藏 adb 接口；
- **反复弹授权框**：开发者选项 → 「撤销 USB 调试授权」→ 拔插重连，重新勾「一律允许」；
- **fastboot devices 为空 + 设备管理器有感叹号**：`references/windows-fastboot-driver.md`；
- **curl 下载报 CRYPT_E_NO_REVOCATION_CHECK**：加 `--ssl-no-revoke`；GitHub 直连慢时换镜像或代理。

## 安全红线

- fastboot 只用 `devices` / `getvar` / `reboot`，禁止一切写入/擦除/解锁命令；
- Zadig 点 Install 前必须核对窗口底部 USB ID 与手机一致（防止给鼠标/键盘误装驱动）；
- 安装驱动、改注册表会弹 UAC（用户账户控制），弹窗前先告知用户点「是」；
- 清理进程只按 PID 杀自己启动的，禁止按进程名批量杀。
