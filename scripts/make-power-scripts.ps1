# make-power-scripts.ps1 — 在桌面生成"软件电源键"双击脚本
# 维护提醒：本文件含中文，必须保存为「UTF-8 with BOM」，否则 PowerShell 5.1 按 GBK 解析会直接语法报错。
# 生成两个文件：唤醒手机.bat（点亮屏幕）/ 熄屏锁屏.bat（熄屏+锁屏）
# 前提：手机 adb 已授权。MIUI 还需开「USB调试(安全设置)」才能模拟按键。
# 用法: powershell -ExecutionPolicy Bypass -File make-power-scripts.ps1
param(
  [string]$AdbPath,
  [string]$DesktopPath
)
$ErrorActionPreference = "Stop"

function Find-Adb {
  $cmd = Get-Command adb -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $candidates = @(
    "$env:USERPROFILE\android-dev\sdk\platform-tools\adb.exe",
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    "$env:ProgramFiles\Android\android-sdk\platform-tools\adb.exe"
  )
  foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
  return $null
}
function Find-Fastboot {
  $cmd = Get-Command fastboot -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $candidates = @(
    "$env:USERPROFILE\android-dev\sdk\platform-tools\fastboot.exe",
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\fastboot.exe",
    "$env:ProgramFiles\Android\android-sdk\platform-tools\fastboot.exe"
  )
  foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
  return $null
}
if (-not $AdbPath)      { $AdbPath      = Find-Adb }
if (-not $DesktopPath)  { $DesktopPath  = [Environment]::GetFolderPath("Desktop") }
if (-not $AdbPath) { "[!] 未找到 adb.exe，请用 -AdbPath 指定（Android platform-tools 内）"; exit 1 }
$FastbootPath = Find-Fastboot

# bat 内容用纯 ASCII 且强制 CRLF 换行——cmd 要求 ANSI + CRLF，UTF-8/LF 会导致解析错乱
$wakeLines = @(
  '@echo off',
  'REM Wake phone screen (replacement for broken power button)',
  "`"$AdbPath`" shell input keyevent 224",
  'if errorlevel 1 (',
  '  echo.',
  '  echo [!] Phone not connected or not authorized. Check USB cable and the popup on phone.',
  ')',
  'timeout /t 2 >nul'
)
$sleepLines = @(
  '@echo off',
  'REM Turn phone screen off and lock (replacement for broken power button)',
  "`"$AdbPath`" shell input keyevent 26",
  'if errorlevel 1 (',
  '  echo.',
  '  echo [!] Phone not connected or not authorized. Check USB cable and the popup on phone.',
  ')',
  'timeout /t 2 >nul'
)
$wake  = ($wakeLines  -join "`r`n") + "`r`n"
$sleep = ($sleepLines -join "`r`n") + "`r`n"

$wakePath  = Join-Path $DesktopPath "唤醒手机.bat"
$sleepPath = Join-Path $DesktopPath "熄屏锁屏.bat"
[System.IO.File]::WriteAllText($wakePath,  $wake,  [System.Text.Encoding]::ASCII)
[System.IO.File]::WriteAllText($sleepPath, $sleep, [System.Text.Encoding]::ASCII)
"[OK] 已生成: $wakePath   （双击=点亮屏幕）"
"[OK] 已生成: $sleepPath   （双击=熄屏+锁屏）"

# 第三件：救砖重启.bat——手机进 fastboot 后双击即重启回系统（电源键坏时的开机手段）
if ($FastbootPath) {
  $rescueLines = @(
    '@echo off'
    'REM Boot phone from fastboot (for power button-less rescue)'
    "set `"FB=$FastbootPath`""
    '"%FB%" devices 2>nul | findstr /i "fastboot" >nul'
    'if errorlevel 1 ('
    '  echo [!] Phone not in fastboot mode. Hold Volume-Down and replug USB cable, then run this again.'
    ') else ('
    '  "%FB%" reboot'
    '  echo [OK] Reboot command sent. Phone is booting to system...'
    ')'
    'timeout /t 3 >nul'
  )
  $rescuePath = Join-Path $DesktopPath "救砖重启.bat"
  [System.IO.File]::WriteAllText($rescuePath, ($rescueLines -join "`r`n") + "`r`n", [System.Text.Encoding]::ASCII)
  "[OK] 已生成: $rescuePath   （手机进 fastboot 后双击=重启回系统）"
}
"`n提醒:"
"  1) 仅在手机插着 USB 线时有效"
"  2) 建议执行一次: adb shell svc power stayon usb   （插线期间屏幕常亮）"
"  3) 小米/红米若报权限错误: 开发者选项打开「USB调试(安全设置)」（需插SIM卡+登录小米账号）"
