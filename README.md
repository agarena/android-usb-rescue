# android-usb-rescue

**手机电源键坏了 / 卡在 fastboot 退不出来 / 黑屏点不亮？一根 USB 数据线 + 一台电脑就能解决——无需 root，不用拆机。**

Broken power button? Stuck in fastboot? Black screen? Rescue your Android phone from your PC with just a USB cable. No root required.

这是一个面向 AI 编程助手（ZCode / Claude Code 等）的技能（skill）：安装后，AI 会按本文流程，带你用电脑完成对手机的"软件接管"。

## 能做什么

| 场景 | 结果 |
|---|---|
| 电源键损坏/失灵，屏幕点不亮 | 双击亮屏、拔插亮屏等 5 种手势 + 授权后一键唤醒脚本，彻底替代电源键 |
| 卡在 fastboot 界面退不出 | 修复 Windows 驱动后 `fastboot reboot` 安全重启回系统 |
| 手机连上电脑但提示 unauthorized（未授权） | 完成指纹授权的完整引导（这是安全机制，无软件绕过，但有绕开死锁的操作顺序） |
| 想找手机相册在哪 / 导出照片 | 相册路径速查表 + MTP 扫描 + `adb pull` 批量导出 |
| 电源键坏了不想天天插线 | 生成桌面双击脚本「唤醒手机.bat / 熄屏锁屏.bat」 |

## 安装

```bash
# 方式一：skills CLI
npx skills add aipanini/android-usb-rescue

# 方式二：手动安装——把本仓库内容放进 AI 工具的技能目录，例如
#   ZCode:        ~/.zcode/skills/android-usb-rescue/
#   Claude Code:  ~/.claude/skills/android-usb-rescue/
#   通用规范:     ~/.agents/skills/android-usb-rescue/
```

前提：电脑装有 Android platform-tools（`adb` / `fastboot` 命令）。没有的话装 [Android 官方 platform-tools](https://developer.android.com/tools/releases/platform-tools) 即可。

> **自动触发开关**：本技能默认标记为「仅点名调用」（`disable-model-invocation: true`），平时不占用 AI 上下文；需要它在你提到手机问题时自动出手，删掉 `SKILL.md` 顶部的这一行即可。

## 使用

安装后对 AI 助手直接说人话即可，例如：

- 「我手机电源键坏了，帮我点亮屏幕」
- 「手机卡在 fastboot 界面退不出来了」
- 「手机相册在哪？帮我把照片拷到电脑上」

也可以点名调用：`/android-usb-rescue 手机开不了机了`。

流程分四步，AI 会先自动检测手机当前状态再走对应分支：

```
第 0 步 检测（adb / fastboot / MTP / 驱动问题码）
第 1 步 不用电源键点亮屏幕 + 完成 USB 调试授权
第 2 步 卡 fastboot 的驱动修复与安全重启（Windows 有独家坑位指南）
第 3 步 软件电源键：插线常亮 + keyevent 唤醒/熄屏 + 桌面双击脚本
第 4 步 相册定位与照片导出
```

## 支持范围

- **品牌**：小米/红米、华为、荣耀、OPPO、一加、真我、vivo/iQOO、三星、Google Pixel 等（品牌差异见 [references/vendor-notes.md](references/vendor-notes.md)，例如三星没有标准 fastboot、小米需要"USB调试（安全设置）"才能模拟按键）
- **平台**：Windows 全流程（含 fastboot 驱动修复的完整踩坑指南）；Linux / macOS / WSL 差异见 [references/linux-mac.md](references/linux-mac.md)
- **Android 版本**：常规安卓 8+，USB 调试需在开发者选项中开启

## 安全承诺

- 对手机的 fastboot 操作**只读优先**：仅允许 `devices` / `getvar` / `reboot`，禁止一切 `flash` / `erase` / `format` / `unlock` 写入命令——不会把可救的手机变砖；
- 不需要 root，不需要解锁 Bootloader；
- 涉及安装驱动、修改注册表的步骤都会先向用户说明并等待确认。

## 目录结构

```
android-usb-rescue/
├── SKILL.md                        # 主流程：状态检测 → 四步救援决策树
├── scripts/
│   ├── detect-phone.ps1            # 一键判定手机当前 USB 状态（只读）
│   ├── fix-fastboot-guid.ps1       # fastboot 驱动"装了但不识别"的接口 GUID 修正（管理员）
│   ├── make-power-scripts.ps1      # 生成桌面「唤醒手机 / 熄屏锁屏」双击脚本
│   └── scan-photos.ps1             # MTP 扫描各相册目录与文件数
└── references/
    ├── windows-fastboot-driver.md  # Windows fastboot 驱动救援全流程（Zadig + GUID 修正）
    ├── vendor-notes.md             # 各品牌差异备注
    └── linux-mac.md                # Linux / macOS / WSL 差异
```

## License

[MIT](LICENSE)
