param(
  [Parameter(Mandatory=$true)][string]$ApplicationBinary,
  [Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]{6,48}$')][string]$RunId,
  [string]$Device='emulator-5554',
  [string]$Flutter='C:/flutter/bin/flutter.bat',
  [string]$Adb='C:/Users/kamilgaraev/AppData/Local/Android/sdk/platform-tools/adb.exe',
  [string]$Aapt='C:/Users/kamilgaraev/AppData/Local/Android/sdk/build-tools/36.0.0/aapt.exe'
)

$ErrorActionPreference='Stop'
$package='ru.prohelper.prohelpers_mobile.bimacceptance'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$apk=(Resolve-Path -LiteralPath $ApplicationBinary).Path
$metadata=& $Aapt dump badging $apk
if ($LASTEXITCODE -ne 0 -or ($metadata | Select-String '^package:').Line -notmatch "^package: name='$([regex]::Escape($package))'") {
  throw 'The APK must use the isolated BIM acceptance applicationId.'
}
$prefix=Join-Path ([IO.Path]::GetTempPath()) "most-bim-$RunId-os-reopen"
$proof=[ordered]@{run_id=$RunId; package=$package; apk_sha256=(Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant(); before=@{}; offline=@{}; after=@{}}

function Invoke-OwnAdb([string[]]$AdbArgs) {
  $value=& $Adb -s $Device @AdbArgs
  if ($LASTEXITCODE -ne 0) { throw 'ADB command failed.' }
  return $value
}

function Read-NetworkProof {
  $wifi=(Invoke-OwnAdb @('shell','settings','get','global','wifi_on') | Out-String).Trim()
  $data=(Invoke-OwnAdb @('shell','settings','get','global','mobile_data') | Out-String).Trim()
  $dump=Invoke-OwnAdb @('shell','dumpsys','connectivity')
  $line=($dump | Select-String '^Active default network:' | Select-Object -First 1).Line
  if (-not $line) { throw 'Android default network state was not reported.' }
  return @{wifi=$wifi; data=$data; active_default_network=$line.Trim(); utc=[DateTime]::UtcNow.ToString('o')}
}

$proof.before=Read-NetworkProof
$phone=Invoke-OwnAdb @('shell','dumpsys','phone')
$proof.no_cellular_subscription=[bool]($phone | Select-String 'mDefaultDataSubId=-1')
if ($proof.before.wifi -ne '1' -or $proof.before.data -ne '1') { throw 'Restore WiFi/data before this isolated test.' }
Invoke-OwnAdb @('shell','am','force-stop',$package) | Out-Null
try {
  Invoke-OwnAdb @('shell','svc','wifi','disable') | Out-Null
  Invoke-OwnAdb @('shell','svc','data','disable') | Out-Null
  if ($proof.no_cellular_subscription) {
    Invoke-OwnAdb @('shell','settings','put','global','mobile_data','0') | Out-Null
    $proof.no_sim_global_data_setting_disabled=$true
  }
  $deadline=[DateTime]::UtcNow.AddSeconds(25)
  do {
    $proof.offline=Read-NetworkProof
    if ($proof.offline.wifi -eq '0' -and $proof.offline.data -eq '0' -and $proof.offline.active_default_network -match '^Active default network:\s*(none|null|-1)$') { break }
    Start-Sleep -Milliseconds 500
  } while ([DateTime]::UtcNow -lt $deadline)
  if ($proof.offline.wifi -ne '0' -or $proof.offline.data -ne '0' -or $proof.offline.active_default_network -notmatch '^Active default network:\s*(none|null|-1)$') { throw 'Android connectivity did not become offline.' }
  $proof.offline_confirmed=$true
  $env:BIM_DEVICE_REPORT_NAME="most-bim-$RunId-reopen-result"
  $env:BIM_DEVICE_REPORT_DIRECTORY=[IO.Path]::GetTempPath()
  Push-Location -LiteralPath $workspace
  try {
    & $Flutter drive --no-pub --target=integration_test/bim_offline_cold_device_test.dart --driver=scripts/tests/bim_device_driver.dart --use-application-binary=$apk -d $Device --keep-app-running *> "$prefix-drive.log"
    $proof.drive_exit=$LASTEXITCODE
  } finally {
    Pop-Location
  }
  $proof.offline_after_drive=Read-NetworkProof
  if ($proof.drive_exit -ne 0) { throw 'Cold reopen drive failed.' }
  $result=Get-Content -LiteralPath (Join-Path ([IO.Path]::GetTempPath()) "$env:BIM_DEVICE_REPORT_NAME.json") -Raw | ConvertFrom-Json
  if ($result.run_id -ne $RunId -or $result.stage -ne 'reopen' -or -not $result.process_restart_verified -or $result.configuration_requests -ne 0 -or $result.native_http_requests -ne 0) { throw 'The actual cold reopen proof does not match this run.' }
  if ($proof.offline_after_drive.wifi -ne '0' -or $proof.offline_after_drive.data -ne '0' -or $proof.offline_after_drive.active_default_network -notmatch '^Active default network:\s*(none|null|-1)$') { throw 'Android connectivity changed during cold reopen.' }
} finally {
  Invoke-OwnAdb @('shell','svc','wifi','enable') | Out-Null
  if ($proof.no_cellular_subscription) { Invoke-OwnAdb @('shell','settings','put','global','mobile_data',$proof.before.data) | Out-Null }
  Invoke-OwnAdb @('shell','svc','data','enable') | Out-Null
  $deadline=[DateTime]::UtcNow.AddSeconds(25)
  do {
    $proof.after=Read-NetworkProof
    if ($proof.after.wifi -eq '1' -and $proof.after.data -eq '1' -and $proof.after.active_default_network -match '^Active default network:\s*\d+$') { break }
    Start-Sleep -Milliseconds 500
  } while ([DateTime]::UtcNow -lt $deadline)
  $proof.restored=($proof.after.wifi -eq '1' -and $proof.after.data -eq '1' -and $proof.after.active_default_network -match '^Active default network:\s*\d+$')
  $proof | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$prefix-network-proof.json" -Encoding utf8
  Write-Output ('RADIOS_RESTORED=' + $proof.restored)
}
if (-not $proof.restored) { throw 'Android connectivity was not restored.' }
Write-Output ('DRIVE_EXIT=' + $proof.drive_exit)
