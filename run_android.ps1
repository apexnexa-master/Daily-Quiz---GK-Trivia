# Run on first connected Android emulator or device (Flutter has no -d android).
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not $env:PUB_CACHE) {
  $env:PUB_CACHE = 'D:\flutter-pub-cache'
}
$env:TEMP = 'D:\gradle-tmp'
$env:TMP = 'D:\gradle-tmp'
New-Item -ItemType Directory -Force -Path $env:PUB_CACHE | Out-Null
New-Item -ItemType Directory -Force -Path $env:TEMP | Out-Null

flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$json = flutter devices --machine | ConvertFrom-Json
$android = $json | Where-Object { $_.targetPlatform -like 'android*' } | Select-Object -First 1

if (-not $android) {
  Write-Host ''
  Write-Host 'No Android emulator or USB device found.'
  Write-Host 'Start an AVD (Android Studio > Device Manager) or connect a phone, then: flutter devices'
  exit 1
}

Write-Host "Using device: $($android.id) ($($android.name))"
flutter run -d $android.id
