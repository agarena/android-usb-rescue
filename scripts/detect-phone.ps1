# detect-phone.ps1 — 检测安卓手机当前 USB 状态（只读，不改任何东西）
# 维护提醒：本文件含中文，必须保存为「UTF-8 with BOM」，否则 PowerShell 5.1 按 GBK 解析会直接语法报错。
# 用法: powershell -ExecutionPolicy Bypass -File detect-phone.ps1
# 输出 adb / fastboot / Windows 设备树三个视角的状态，并给出下一步建议。
param(
  [string]$AdbPath,
  [string]$FastbootPath
)
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Find-Tool([string]$name) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $candidates = @(
    "$env:USERPROFILE\android-dev\sdk\platform-tools\$name.exe",
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\$name.exe",
    "$env:ProgramFiles\Android\android-sdk\platform-tools\$name.exe"
  )
  foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
  return $null
}
if (-not $AdbPath)      { $AdbPath      = Find-Tool "adb" }
if (-not $FastbootPath) { $FastbootPath = Find-Tool "fastboot" }

"=== 1. ADB 视角 ==="
if (-not $AdbPath) { "adb 未找到（需安装 Android platform-tools）" }
else {
  & $AdbPath start-server 2>$null | Out-Null
  $lines = & $AdbPath devices 2>$null | Select-Object -Skip 1 | Where-Object { $_.Trim() -ne "" }
  if (-not $lines) { "adb: 无设备" }
  foreach ($l in $lines) {
    $parts = $l -split "`t"
    "adb: $($parts[0])  状态=$($parts[1])"
    if ($parts[1] -eq "device")       { "  -> 已授权，可直接控制（走第 3 步：软件电源键）" }
    elseif ($parts[1] -eq "unauthorized") { "  -> 未授权：先在手机上点亮屏幕，点『允许 USB 调试』（走第 1 步）" }
    elseif ($parts[1] -eq "offline")  { "  -> 离线：拔插数据线重试" }
  }
}

"`n=== 2. FASTBOOT 视角 ==="
if (-not $FastbootPath) { "fastboot 未找到" }
else {
  $fb = (& $FastbootPath devices 2>$null | Where-Object { $_.Trim() -ne "" })
  if ($fb) {
    foreach ($l in $fb) { "fastboot: $l" }
    "  -> 手机在 fastboot 界面（走第 2 步：fastboot reboot 救回）"
  } else { "fastboot: 无设备（注意：三星下载模式不在此列）" }
}

"`n=== 3. Windows 设备树视角 ==="
$vidPattern = "VID_18D1|VID_2717|VID_04E8|VID_12D1|VID_22D9|VID_2A45|VID_2A70|VID_2D95|VID_19D2|VID_0BB4|VID_0FCE|VID_2A62"
$devs = Get-PnpDevice -PresentOnly | Where-Object {
  $_.InstanceId -match $vidPattern -or $_.Class -eq "WPD" -or $_.FriendlyName -match "Android|MTP"
}
if (-not $devs) { "未检测到任何手机相关设备（检查数据线是否支持数据传输、换 USB 口）" }
foreach ($d in $devs) {
  $id = $d.InstanceId
  $svc  = (Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_Service -ErrorAction SilentlyContinue).Data
  $prob = (Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_ProblemCode -ErrorAction SilentlyContinue).Data
  "[$($d.Status)] $($d.FriendlyName)  Class=$($d.Class)  Service=$svc  Problem=$prob"
  "         $id"
  if ($d.Status -eq "Error" -and $prob -eq 28) { "  -> 问题码 28 = 驱动未安装（fastboot 模式见 references/windows-fastboot-driver.md）" }
  if ($d.Status -eq "OK" -and -not $svc -and $id -match "PID_D00D") {
    "  -> 状态 OK 但没绑驱动服务：假象，实际不可用（同样走驱动修复）"
  }
  if ($d.Class -eq "WPD") { "  -> MTP 便携设备：资源管理器可直接浏览文件（走第 4 步找相册）" }
}
"`n=== 判定完毕 ==="
