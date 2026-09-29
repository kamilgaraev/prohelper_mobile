param(
    [Parameter(Mandatory = $true)]
    [int] $ViewerPid,
    [string] $Device = 'emulator-5554',
    [string] $AdbPath = 'C:/Users/kamilgaraev/AppData/Local/Android/sdk/platform-tools/adb.exe'
)

$ErrorActionPreference = 'Stop'
$bimPackage = 'ru.prohelper.prohelpers_mobile.bimacceptance'
$bimActualPid = (& $AdbPath -s $Device shell pidof $bimPackage).Trim()
if ($bimActualPid -ne "$ViewerPid") { throw 'The PID must belong to the isolated BIM test package.' }
$bimSize = (& $AdbPath -s $Device shell wm size) -join "`n"
if ($bimSize -match 'Override size:\s*(\d+)x(\d+)') {
    $bimScreenWidth = [int] $Matches[1]
    $bimScreenHeight = [int] $Matches[2]
} elseif ($bimSize -match 'Physical size:\s*(\d+)x(\d+)') {
    $bimScreenWidth = [int] $Matches[1]
    $bimScreenHeight = [int] $Matches[2]
} else { throw 'Cannot read Android display size.' }
$bimX = [int] ($bimScreenWidth / 2)
$bimY = [int] ($bimScreenHeight / 2)
Write-Output "Native input display: ${bimScreenWidth}x${bimScreenHeight}; center ${bimX},${bimY}"
$bimSent = [Collections.Generic.HashSet[string]]::new()
$bimWatch = [Diagnostics.Stopwatch]::StartNew()
function Get-BimActivityState {
    $bimActivityDump = (& $AdbPath -s $Device shell dumpsys activity activities) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read native activity state.' }
    $bimActivityMatch = [regex]::Match($bimActivityDump,
        '(?s)\* Hist\s+#\d+: ActivityRecord\{[^\r\n]*' + [regex]::Escape($bimPackage) + '[^\r\n]*\}.*?\bstate=(\w+)')
    if (-not $bimActivityMatch.Success) { throw 'Own native activity state is missing.' }
    return $bimActivityMatch.Groups[1].Value
}
while ($bimWatch.Elapsed.TotalMinutes -lt 8) {
    $bimLog = (& $AdbPath -s $Device logcat -d "--pid=$ViewerPid" -s flutter) -join "`n"
    if ($bimLog -match 'Some tests failed') { throw 'The viewer test failed; inspect its driver report.' }
    foreach ($bimPhase in @('native_pick_17_ready', 'native_pick_18_ready', 'native_drag_ready', 'background_ready')) {
        if ($bimLog.Contains("BIM_DEVICE_PHASE $bimPhase") -and $bimSent.Add($bimPhase)) {
            switch ($bimPhase) {
                'native_drag_ready' { & $AdbPath -s $Device shell input swipe $bimX $bimY ($bimX + 120) ($bimY + 60) 500 }
                'background_ready' {
                    try {
                        & $AdbPath -s $Device shell input keyevent KEYCODE_HOME
                        $bimBackgroundWatch = [Diagnostics.Stopwatch]::StartNew()
                        do {
                            $bimActivityState = Get-BimActivityState
                            if ($bimActivityState -eq 'STOPPED') { break }
                            Start-Sleep -Milliseconds 350
                        } while ($bimBackgroundWatch.Elapsed.TotalSeconds -lt 20)
                        if ($bimActivityState -ne 'STOPPED') { throw 'Own Android activity did not reach STOPPED after HOME.' }
                        Write-Output 'Own Android activity state after HOME: STOPPED'
                        Start-Sleep -Seconds 3
                    } finally {
                        & $AdbPath -s $Device shell am start -n "$bimPackage/ru.prohelper.prohelpers_mobile.MainActivity" | Out-Null
                    }
                    Write-Output ('Own Android activity state after resume: ' + (Get-BimActivityState))
                }
                default { & $AdbPath -s $Device shell input tap $bimX $bimY }
            }
            if ($LASTEXITCODE -ne 0) { throw "ADB input failed for $bimPhase" }
            Write-Output "Native input sent: $bimPhase; PID $ViewerPid"
            if ($bimPhase -eq 'background_ready') { return }
        }
    }
    Start-Sleep -Milliseconds 500
}
throw 'Timed out waiting for BIM native input markers.'
