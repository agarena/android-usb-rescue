# scan-photos.ps1 — 通过 MTP 扫描手机相册各目录与文件数（只读）
# 维护提醒：本文件含中文，必须保存为「UTF-8 with BOM」，否则 PowerShell 5.1 按 GBK 解析会直接语法报错。
# 用法: powershell -ExecutionPolicy Bypass -File scan-photos.ps1
# 前提: 手机以「传输文件(MTP)」模式连接，手机端已允许数据访问。
$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$shell = New-Object -ComObject Shell.Application
$computer = $shell.NameSpace(0x11)   # 此电脑
$phones = @($computer.Items() | Where-Object { $_.Class -match "ComputerFolder|Portable" -or $true } | Where-Object {
  # 便携设备在"此电脑"下表现为带 MTP/便携属性的项；直接按类型描述过滤
  $dt = $computer.GetDetailsOf($_, 1)   # 类型列
  $dt -match "便携|Multifunction|Portable|MTP|电话|手机|Phone"
})
if (-not $phones) { "未发现便携设备。确认手机选了『传输文件』且手机端点了『允许访问数据』。"; exit }

foreach ($phone in $phones) {
  "=== 手机: $($phone.Name) ==="
  $storages = $phone.GetFolder().Items()
  foreach ($storage in $storages) {
    "  存储: $($storage.Name)"
    $sns = $shell.NameSpace($storage)
    if (-not $sns) { continue }
    foreach ($topName in @("DCIM", "Pictures")) {
      $top = $sns.Items() | Where-Object { $_.Name -eq $topName } | Select-Object -First 1
      if (-not $top) { continue }
      $tns = $shell.NameSpace($top)
      foreach ($dir in $tns.Items()) {
        if (-not $dir.IsFolder) { continue }
        $dns = $shell.NameSpace($dir)
        $cnt = 0; if ($dns) { $cnt = @($dns.Items()).Count }
        "    $topName\$($dir.Name)  ($cnt 项)"
      }
    }
    # 相机目录给出最新样例
    $dcim = $sns.Items() | Where-Object { $_.Name -eq "DCIM" } | Select-Object -First 1
    if ($dcim) {
      $dns2 = $shell.NameSpace($dcim)
      $camera = $dns2.Items() | Where-Object { $_.Name -eq "Camera" } | Select-Object -First 1
      if ($camera) {
        $cns = $shell.NameSpace($camera)
        $files = @($cns.Items() | Where-Object { -not $_.IsFolder })
        "    DCIM/Camera 文件数: $($files.Count)"
        if ($files.Count -gt 0) {
          # 找"修改日期"列索引（不同 Windows 版本列号不同）
          $dateIdx = -1
          for ($i = 0; $i -le 40; $i++) {
            $h = $cns.GetDetailsOf($null, $i)
            if ($h -match "修改日期|Date modified") { $dateIdx = $i; break }
          }
          $last = $files | Select-Object -Last 1
          if ($dateIdx -ge 0) { "    最新一张: $($last.Name)  $($cns.GetDetailsOf($last, $dateIdx))" }
          else { "    最新一张: $($last.Name)" }
        }
      }
    }
  }
}
