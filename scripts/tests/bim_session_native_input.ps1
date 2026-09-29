param(
    [Parameter(Mandatory = $true)]
    [int] $ViewerPid,
    [string] $Device = 'emulator-5554',
    [string] $AdbPath = 'C:/Users/kamilgaraev/AppData/Local/Android/sdk/platform-tools/adb.exe'
)

$ErrorActionPreference = 'Stop'
$bimPackage = 'ru.prohelper.prohelpers_mobile.bimacceptance'
if ((& $AdbPath -s $Device shell pidof $bimPackage).Trim() -ne "$ViewerPid") {
    throw 'The PID must belong to the isolated BIM test package.'
}
$bimSent = [Collections.Generic.HashSet[string]]::new()
$bimWatch = [Diagnostics.Stopwatch]::StartNew()
$bimPointerDown = $false
$bimCursor = $null
try {
    while ($bimWatch.Elapsed.TotalMinutes -lt 35) {
        $bimLog = (& $AdbPath -s $Device logcat -d "--pid=$ViewerPid" -s flutter) -join "`n"
        if ($bimLog -match 'Some tests failed') { throw 'The session test failed; inspect its driver report.' }
        if (-not $bimSent.Contains('cursor') -and $bimLog -match 'BIM_SESSION_PHASE native_cursor_input_ready (\{[^\r\n]+\})') {
            $bimCursor = $Matches[1] | ConvertFrom-Json
            foreach ($bimCoordinate in @($bimCursor.x, $bimCursor.y, $bimCursor.move_x, $bimCursor.move_y)) {
                if ($bimCoordinate -isnot [ValueType] -or $bimCoordinate -lt 0 -or $bimCoordinate -gt 5000) { throw 'Invalid native cursor coordinates.' }
            }
            & $AdbPath -s $Device shell input touchscreen motionevent DOWN ([int]$bimCursor.x) ([int]$bimCursor.y)
            if ($LASTEXITCODE -ne 0) { throw 'Native cursor DOWN failed.' }
            $bimPointerDown = $true
            $bimSent.Add('cursor') | Out-Null
            Write-Output "Native cursor DOWN: $($bimCursor.x),$($bimCursor.y); PID $ViewerPid"
        }
        if ($bimPointerDown) {
            if ($bimLog.Contains('BIM_SESSION_PHASE native_cursor_input_complete')) {
                & $AdbPath -s $Device shell input touchscreen motionevent UP ([int]$bimCursor.move_x) ([int]$bimCursor.move_y)
                if ($LASTEXITCODE -ne 0) { throw 'Native cursor UP failed.' }
                $bimPointerDown = $false
                Write-Output 'Native cursor UP after the cursor input completion marker.'
            } else {
                & $AdbPath -s $Device shell input touchscreen motionevent MOVE ([int]$bimCursor.move_x) ([int]$bimCursor.move_y)
                if ($LASTEXITCODE -ne 0) { throw 'Native cursor MOVE failed.' }
            }
        }
        if (-not $bimSent.Contains('selection') -and $bimLog -match 'BIM_SESSION_PHASE native_selection_input_ready (\{[^\r\n]+\})') {
            if ($bimPointerDown) { throw 'Selection began before the cursor pointer was released.' }
            $bimSelection = $Matches[1] | ConvertFrom-Json
            foreach ($bimCoordinate in @($bimSelection.x, $bimSelection.y)) {
                if ($bimCoordinate -isnot [ValueType] -or $bimCoordinate -lt 0 -or $bimCoordinate -gt 5000) { throw 'Invalid native selection coordinates.' }
            }
            & $AdbPath -s $Device shell input tap ([int]$bimSelection.x) ([int]$bimSelection.y)
            if ($LASTEXITCODE -ne 0) { throw 'Native selection tap failed.' }
            $bimSent.Add('selection') | Out-Null
            Write-Output "Native selection tap: $($bimSelection.x),$($bimSelection.y); PID $ViewerPid"
            return
        }
        if (-not $bimPointerDown -and $bimLog.Contains('BIM_SESSION_DIAGNOSTIC_RESULT')) {
            Write-Output 'Native cursor diagnostic finished; desktop pair was not verified.'
            return
        }
        Start-Sleep -Milliseconds $(if ($bimPointerDown) { 2000 } else { 350 })
    }
    throw 'Timed out waiting for BIM native session input markers.'
} finally {
    if ($bimPointerDown) {
        & $AdbPath -s $Device shell input touchscreen motionevent UP ([int]$bimCursor.move_x) ([int]$bimCursor.move_y) | Out-Null
    }
}
