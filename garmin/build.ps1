# Builds bin\bgm.prg for the Forerunner 970.
# Usage: powershell -File build.ps1
$ErrorActionPreference = 'Stop'

$sdk = (Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg").Trim().TrimEnd('\')
$jdk = Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Directory | Sort-Object Name -Descending | Select-Object -First 1
$key = "$env:USERPROFILE\.garmin-ciq\developer_key.der"

$env:PATH = "$($jdk.FullName)\bin;$env:PATH"

Push-Location $PSScriptRoot
try {
    & "$sdk\bin\monkeyc.bat" -f monkey.jungle -o bin\bgm.prg -y $key -d fr970 -w -l 2
    if ($LASTEXITCODE -ne 0) { throw "monkeyc failed with exit code $LASTEXITCODE" }
    Get-Item bin\bgm.prg | Select-Object Name, Length, LastWriteTime
} finally {
    Pop-Location
}
