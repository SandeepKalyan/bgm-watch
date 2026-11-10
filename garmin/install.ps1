# Copies bin\bgm.prg onto a Garmin watch connected over USB.
# Usage: powershell -File install.ps1
#
# The watch shows up in Windows as a media device, not a drive letter, so the
# copy goes through the Explorer shell rather than Copy-Item.
$ErrorActionPreference = 'Stop'

$prg = Join-Path $PSScriptRoot 'bin\bgm.prg'
if (-not (Test-Path $prg)) { throw "Build first: $prg does not exist." }

function Get-Child($item, $name) {
    $item.GetFolder.Items() | Where-Object { $_.Name -eq $name } | Select-Object -First 1
}

$shell = New-Object -ComObject Shell.Application
$apps = $null
foreach ($device in $shell.NameSpace(17).Items()) {      # 17 = This PC
    if (-not $device.IsFolder -or $device.Name -match '^\w+ \(\w:\)$') { continue }   # skip drives
    $storage = Get-Child $device 'Internal Storage'
    if (-not $storage) { continue }
    $garmin = Get-Child $storage 'GARMIN'
    if (-not $garmin) { continue }
    $apps = Get-Child $garmin 'Apps'
    if ($apps) { "Watch: $($device.Name)"; break }
}
if (-not $apps) {
    throw "No Garmin watch found. Plug it in with a data cable and unlock it."
}

$folder = $apps.GetFolder
$name = [IO.Path]::GetFileNameWithoutExtension($prg)
$before = $folder.Items() | Where-Object { $_.Name -match "^$name(\.prg)?$" } | Select-Object -First 1
$beforeStamp = if ($before) { $folder.GetDetailsOf($before, 3) + '|' + $folder.GetDetailsOf($before, 2) } else { '' }
if ($before) { "An older $name is on the watch. If Windows asks whether to replace it, choose Replace." }

$folder.CopyHere($prg, 16)     # 16 = answer "Yes to All"; media devices may still ask

$done = $false
for ($i = 0; $i -lt 60 -and -not $done; $i++) {
    Start-Sleep -Seconds 1
    $now = $folder.Items() | Where-Object { $_.Name -match "^$name(\.prg)?$" } | Select-Object -First 1
    if ($now) {
        $stamp = $folder.GetDetailsOf($now, 3) + '|' + $folder.GetDetailsOf($now, 2)
        $done = (-not $before) -or ($stamp -ne $beforeStamp)
    }
}

if ($done) {
    "Copied $name ($($folder.GetDetailsOf($now, 2))). Unplug the watch to install it."
} elseif ($before) {
    "Copy sent, but the file on the watch looks unchanged. Check for a Replace prompt on screen."
    exit 1
} else {
    "Copy sent, but the file is not visible on the watch after 60 s."
    exit 1
}
