# Windows 下 fastboot 驱动救援

适用症状：手机屏幕显示 fastboot，`fastboot devices` 却输出为空。这是 Windows 侧驱动问题，手机本身没坏。

## 第 1 步：诊断（判定属于哪种失败形态）

用管理员与否无关，普通 PowerShell 即可：

```powershell
Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match "VID_18D1|VID_2717|VID_04E8|VID_2A45|VID_2D95" } |
  ForEach-Object {
    $id = $_.InstanceId
    "[$($_.Status)] $($_.FriendlyName)  $id"
    "  Service=" + (Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_Service).Data
    "  Problem=" + (Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_ProblemCode).Data
  }
```

判读表（也可直接跑 `scripts/detect-phone.ps1` 自动判读）：

| 现象 | 结论 | 处理 |
|---|---|---|
| 完全找不到手机设备 | 线/口/模式问题 | 换支持数据的线、换 USB 2.0 口；确认手机真在 fastboot 界面 |
| Status=Error，Problem=28 | 驱动未安装 | → 第 2 步 |
| Status=**OK** 但 Service 为空 | 假象！实际没有任何驱动绑定 | → 第 2 步（别被 OK 骗了，以 Service 为准） |
| Service=WinUSB 但 fastboot devices 仍为空 | 接口 GUID 不匹配（**最常见坑**） | → 第 3 步 |

背景知识：`fastboot.exe` 只通过接口 GUID `{F72FE0D4-CBCB-407d-8814-9ED673D0DD6B}`（Google 驱动声明值）寻找设备。Zadig 安装的通用 WinUSB 驱动功能完全正常，但注册的是自己生成的随机 GUID——驱动装得再对，fastboot 也"看不见"。所以 GUID 修正是必做步骤。

## 第 2 步：安装 WinUSB 驱动（Zadig 工具）

为什么不用 Google 官方驱动：其 INF（`usb_driver_r13-windows.zip`）只列了 Pixel 系列硬件 ID，国产手机 fastboot 通用 ID `USB\VID_18D1&PID_D00D` 不在列；手工改 INF 又过不了包签名校验（`pnputil` 直接拒绝）。Zadig（libwdi）运行时自签驱动包，是最省事的合法途径。

下载：
- 官方：<https://github.com/pbatard/libwdi/releases>（单文件 exe，约 5MB）
- 国内网络注意：GitHub 直连慢/失败时，`curl` 加 `--ssl-no-revoke`（绕过吊销检查失败报错 `CRYPT_E_NO_REVOCATION_CHECK`）或走镜像。

操作步骤（需要用户点一次 UAC）：
1. 运行 zadig.exe，UAC 点「是」；
2. 顶部下拉框选中手机设备，形如 `Android (USB\VID_18D1&PID_D00D)`；
3. **核对窗口底部状态栏 `USB ID` 必须是手机的实际值**（如 `18D1 D00D`）——这是安全闸门，值不对（比如显示鼠标 `046D` 开头）绝对不能点安装；
4. 目标驱动选默认 `WinUSB`，点 `Install Driver`，等 `Driver Installation: SUCCESS`；
5. 让设备重新枚举一次：拔插数据线，或管理员执行 `pnputil /restart-device "<设备实例ID>"`。

## 第 3 步：接口 GUID 修正

管理员运行（自动定位 PID_D00D 设备、写 Google GUID、重启设备节点）：

```
powershell -ExecutionPolicy Bypass -File scripts\fix-fastboot-guid.ps1
```

手动等价操作（管理员 PowerShell）：

```powershell
reg.exe add "HKLM\SYSTEM\CurrentControlSet\Enum\<设备实例ID>\Device Parameters" /v DeviceInterfaceGUIDs /t REG_MULTI_SZ /d "{F72FE0D4-CBCB-407d-8814-9ED673D0DD6B}" /f
pnputil /restart-device "<设备实例ID>"
```

验证（普通窗口即可）：`fastboot devices` 出现 `序列号  fastboot` → 立即 `fastboot reboot` 重启回系统。

## 常见 fastboot USB ID 速查

以实际枚举为准，不要硬套：

| VID:PID | 说明 |
|---|---|
| `18D1:D00D` | 通用 fastboot（小米/一加/真我/努比亚等多数国产机） |
| `18D1:4EE0` | Google Pixel 系列 bootloader |
| `2717:FF48` 等 | 小米系统模式（MTP+ADB 复合） |
| `04E8:6860` | 三星 MTP（三星无标准 fastboot，见 vendor-notes） |

## 失败形态

- **杀毒软件/管家拦截驱动安装**：临时放行 libwdi 生成的驱动包；
- **USB 3.0 口兼容性差**：改插 USB 2.0 口或主板后置口；
- **线材只能充电不能传数据**：换一根确认能传文件的线；
- **企业组策略禁止未签名驱动**：Zadig 装不上时，改走 WSL 路线——`winget install usbipd-win` 后 `usbipd bind` + `usbipd attach --wsl`，把设备直通给 WSL，在 WSL 里用 Linux 的 fastboot（无驱动问题）执行 `fastboot reboot`；
- **每次拔插后 fastboot 又看不见**：Zadig 驱动是按设备实例绑定的，序列号不变的同一台机不会丢；若换端口后丢，重跑第 3 步脚本即可。
