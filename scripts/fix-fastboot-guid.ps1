# fix-fastboot-guid.ps1 — 让 Windows 的 fastboot 认出已装 WinUSB 驱动的手机
# 维护提醒：本文件含中文，必须保存为「UTF-8 with BOM」，否则 PowerShell 5.1 按 GBK 解析会直接语法报错。
# 原理：fastboot.exe 只通过 Google 驱动声明的接口 GUID {F72FE0D4-CBCB-407d-8814-9ED673D0DD6B}
#       查找设备；Zadig 装的通用 WinUSB 注册的是随机 GUID，驱动正常但 fastboot 永远看不见。
#       本脚本把设备接口 GUID 改为 Google 值并重启设备节点。
# 用法（需管理员 PowerShell）:
#   powershell -ExecutionPolicy Bypass -File fix-fastboot-guid.ps1                # 自动定位 PID_D00D 设备
#   powershell -ExecutionPolicy Bypass -File fix-fastboot-guid.ps1 -InstanceId "USB\VID_XXXX&PID_D00D\序列号"
param(
  [string]$InstanceId,
  [string]$InterfaceGuid = "{F72FE0D4-CBCB-407d-8814-9ED673D0DD6B}"
)
$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  "[!] 需要管理员权限。请用『管理员 PowerShell』运行；"
  "    或由 AI 助手通过 Start-Process powershell -Verb RunAs 提升（用户点一次 UAC 确认）。"
  exit 1
}

if (-not $InstanceId) {
  $d = Get-PnpDevice -PresentOnly | Where-Object {
    $_.InstanceId -match "&PID_D00D" -and $_.Status -eq "OK"
  } | Select-Object -First 1
  if ($d) { $InstanceId = $d.InstanceId }
}
if (-not $InstanceId) {
  "[!] 未自动找到 fastboot 设备（默认匹配 PID_D00D）。"
  "    先运行 detect-phone.ps1 拿到设备实例 ID，再用 -InstanceId 指定。"
  exit 1
}
"[i] 目标设备: $InstanceId"

$key = "HKLM\SYSTEM\CurrentControlSet\Enum\$InstanceId\Device Parameters"
$r = & reg.exe add "$key" /v DeviceInterfaceGUIDs /t REG_MULTI_SZ /d "$InterfaceGuid" /f 2>&1
"写入 GUID: $r"
if ("$r" -notmatch "操作成功完成|success") { "[!] 注册表写入可能失败，检查上方输出"; exit 1 }

$r2 = & pnputil /restart-device "$InstanceId" 2>&1
$r2 | ForEach-Object { "[i] $_" }

"`n验证（非管理员窗口即可）:"
"  fastboot devices"
"出现序列号 + fastboot 即成功，随后 fastboot reboot 重启回系统。"
