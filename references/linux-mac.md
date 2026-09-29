# Linux / macOS / WSL 差异

核心流程（检测 → 授权 → fastboot reboot → 软件电源键 → 相册导出）与 Windows 完全一致，主要差别是**没有驱动地狱**：Linux 与 macOS 的 fastboot/adb 无需装驱动即可识别绝大多数手机。

## 安装工具

```bash
# macOS
brew install android-platform-tools

# Debian / Ubuntu
sudo apt install android-tools-adb android-tools-fastboot

# Arch
sudo pacman -S android-tools
```

## Linux udev 规则（adb/fastboot 报 "no permissions" 时）

`fastboot devices` 能看到但报权限错误时，写 udev 规则：

```bash
sudo tee /etc/udev/rules.d/51-android.rules > /dev/null <<'EOF'
SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTR{idVendor}=="2717", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTR{idVendor}=="04e8", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTR{idVendor}=="12d1", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTR{idVendor}=="22d9", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTR{idVendor}=="2a70", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTR{idVendor}=="2d95", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTR{idVendor}=="19d2", MODE="0666", GROUP="plugdev"
EOF
sudo usermod -aG plugdev $USER
sudo udevadm control --reload-rules
sudo udevadm trigger
```

改完重新拔插数据线。idVendor 对照：`18d1` Google/通用 fastboot、`2717` 小米、`04e8` 三星、`12d1` 华为荣耀、`22d9` OPPO、`2a70` 一加、`2d95` vivo、`19d2` 中兴。

## WSL（Windows 里的 Linux 子系统）

WSL 本身看不到 USB 设备，用 usbipd-win 直通后即可完全绕开 Windows 驱动问题（Windows 驱动装不上时的替代路线）：

```powershell
# Windows 侧（管理员）
winget install usbipd
usbipd list                                    # 找到手机的 BUSID
usbipd bind --busid <BUSID>
usbipd attach --wsl --busid <BUSID>
```

```bash
# WSL 侧
lsusb                                          # 确认能看到手机
fastboot devices && fastboot reboot
```

注意：`fastboot reboot` 执行完手机即重启，WSL 里设备会随即消失，属正常现象。

## 与 Windows 流程的对照

| Windows 步骤 | Linux/macOS 对应 |
|---|---|
| Zadig 装驱动 + GUID 修正 | 不需要，开箱即用（仅 udev 规则） |
| `svc power stayon usb` | 相同 |
| 桌面 .bat 双击脚本 | 改用 shell alias：`alias phonewake='adb shell input keyevent 224'` |
| 相册 MTP（资源管理器） | `adb pull`，或装 `jmtpfs`/`go-mtpfs` 挂载 MTP |
