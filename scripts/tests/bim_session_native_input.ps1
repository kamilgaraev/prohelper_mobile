param(
    [Parameter(Mandatory = $true)]
    [int] $ViewerPid,
    [string] $Device = 'emulator-5554',
    [string] $AdbPath = 'C:/Users/kamilgaraev/AppData/Local/Android/sdk/platform-tools/adb.exe'
)

$ErrorActionPreference = 'Stop'
$bimPackage = 'ru.prohelper.prohelpers_mobile.bimacceptance'

function Invoke-BimAdb {
    param(
        [Parameter(Mandatory = $true)] [string] $Stage,
        [Parameter(Mandatory = $true)] [string[]] $Arguments,
        [switch] $Quiet
    )

    $startedAt = [DateTimeOffset]::UtcNow
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $AdbPath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$startInfo.ArgumentList.Add($argument) }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw "Could not start adb stage '$Stage'." }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult().Trim()
    $stderr = $stderrTask.GetAwaiter().GetResult().Trim()
    $exitCode = $process.ExitCode
    $process.Dispose()
    $finishedAt = [DateTimeOffset]::UtcNow

    if (-not $Quiet) {
        $safeStdout = if ($stdout.Length -gt 1800) { $stdout.Substring(0, 1800) } else { $stdout }
        $safeStderr = if ($stderr.Length -gt 1800) { $stderr.Substring(0, 1800) } else { $stderr }
        [pscustomobject]@{
            stage = $Stage
            started_utc = $startedAt.ToString('o')
            finished_utc = $finishedAt.ToString('o')
            exit_code = $exitCode
            stdout = $safeStdout
            stderr = $safeStderr
        } | ConvertTo-Json -Compress | Write-Host
    }

    if ($exitCode -ne 0 -or "$stdout`n$stderr" -match '(?im)^\s*(Error:|Unknown command:|Invalid arguments:|Usage: input)') {
        throw "ADB stage '$Stage' failed (exit $exitCode)."
    }
    return [pscustomobject]@{ stdout = $stdout; stderr = $stderr; exit_code = $exitCode }
}

$deviceArgs = @('-s', $Device, 'shell')
$pidResult = Invoke-BimAdb -Stage 'preflight_pid' -Arguments ($deviceArgs + @('pidof', $bimPackage))
if ($pidResult.stdout.Trim() -ne "$ViewerPid") {
    throw 'The PID must belong to the isolated BIM test package.'
}

$windowResult = Invoke-BimAdb -Stage 'preflight_window_focus' -Arguments ($deviceArgs + @('dumpsys', 'window'))
$focusLines = @($windowResult.stdout -split "`r?`n" | Where-Object { $_ -match 'm(?:CurrentFocus|FocusedApp|FocusedWindow)\b' })
$focusSummary = $focusLines -join ' | '
if (-not $focusSummary -or $focusSummary -notmatch [regex]::Escape($bimPackage)) {
    throw "The isolated BIM app is not the focused window: $focusSummary"
}
Write-Output ([pscustomobject]@{ stage = 'focused_window'; observed_utc = [DateTimeOffset]::UtcNow.ToString('o'); focus = $focusSummary } | ConvertTo-Json -Compress)

$sizeResult = Invoke-BimAdb -Stage 'preflight_display_size' -Arguments ($deviceArgs + @('wm', 'size'))
$densityResult = Invoke-BimAdb -Stage 'preflight_display_density' -Arguments ($deviceArgs + @('wm', 'density'))
$displayMatch = [regex]::Match($sizeResult.stdout, '(?m)(?:Override size|Physical size):\s*(\d+)x(\d+)')
if (-not $displayMatch.Success) { throw 'Could not determine the Android display dimensions.' }
$displayWidth = [int]$displayMatch.Groups[1].Value
$displayHeight = [int]$displayMatch.Groups[2].Value
$bimDisplay = [pscustomobject]@{
    stage = 'display_geometry'
    observed_utc = [DateTimeOffset]::UtcNow.ToString('o')
    width = $displayWidth
    height = $displayHeight
    size = $sizeResult.stdout
    density = $densityResult.stdout
} | ConvertTo-Json -Compress
Write-Output $bimDisplay

$bimSent = [Collections.Generic.HashSet[string]]::new()
$bimWatch = [Diagnostics.Stopwatch]::StartNew()
$bimPointerDown = $false
$bimCursor = $null
try {
    while ($bimWatch.Elapsed.TotalMinutes -lt 35) {
        $bimLog = (Invoke-BimAdb -Stage 'poll_flutter_log' -Arguments ($deviceArgs + @('logcat', '-d', "--pid=$ViewerPid", '-s', 'flutter')) -Quiet).stdout
        if ($bimLog -match 'Some tests failed') { throw 'The session test failed; inspect its driver report.' }

        if (-not $bimSent.Contains('cursor') -and $bimLog -match 'BIM_SESSION_PHASE native_cursor_input_ready (\{[^\r\n]+\})') {
            $bimCursor = $Matches[1] | ConvertFrom-Json
            foreach ($bimCoordinate in @($bimCursor.x, $bimCursor.y, $bimCursor.move_x, $bimCursor.move_y)) {
                if ($bimCoordinate -isnot [ValueType] -or $bimCoordinate -lt 0 -or $bimCoordinate -gt 5000) { throw 'Invalid native cursor coordinates.' }
            }
            foreach ($bimCoordinate in @($bimCursor.x, $bimCursor.move_x)) {
                if ($bimCoordinate -ge $displayWidth) { throw 'Native cursor X coordinate is outside the Android display.' }
            }
            foreach ($bimCoordinate in @($bimCursor.y, $bimCursor.move_y)) {
                if ($bimCoordinate -ge $displayHeight) { throw 'Native cursor Y coordinate is outside the Android display.' }
            }

            $bimPointerDown = $true
            $swipeResult = Invoke-BimAdb -Stage 'native_cursor_swipe' -Arguments ($deviceArgs + @('input', 'touchscreen', 'swipe', [string][int]$bimCursor.x, [string][int]$bimCursor.y, [string][int]$bimCursor.move_x, [string][int]$bimCursor.move_y, '500'))
            if ($swipeResult.exit_code -ne 0) { throw 'Native cursor swipe failed.' }
            $bimPointerDown = $false
            $bimSent.Add('cursor') | Out-Null
            Write-Output "Native cursor swipe sent for PID $ViewerPid."
        }

        if ($bimSent.Contains('cursor') -and -not $bimSent.Contains('cursor_release') -and $bimLog.Contains('BIM_SESSION_PHASE native_cursor_input_complete')) {
            $releaseX = if ($null -ne $bimCursor) { [string][int]$bimCursor.move_x } else { '0' }
            $releaseY = if ($null -ne $bimCursor) { [string][int]$bimCursor.move_y } else { '0' }
            $releaseResult = Invoke-BimAdb -Stage 'native_cursor_release_tap' -Arguments ($deviceArgs + @('input', 'touchscreen', 'tap', $releaseX, $releaseY))
            if ($releaseResult.exit_code -ne 0) { throw 'Native cursor release tap failed.' }
            $bimSent.Add('cursor_release') | Out-Null
            Write-Output 'Native cursor release tap sent after the test completion marker.'
        }

        if (-not $bimSent.Contains('selection') -and $bimLog -match 'BIM_SESSION_PHASE native_selection_input_ready (\{[^\r\n]+\})') {
            if ($bimPointerDown) { throw 'Selection began before the cursor gesture completed.' }
            $bimSelection = $Matches[1] | ConvertFrom-Json
            foreach ($bimCoordinate in @($bimSelection.x, $bimSelection.y)) {
                if ($bimCoordinate -isnot [ValueType] -or $bimCoordinate -lt 0 -or $bimCoordinate -gt 5000) { throw 'Invalid native selection coordinates.' }
            }
            if ($bimSelection.x -ge $displayWidth -or $bimSelection.y -ge $displayHeight) { throw 'Native selection coordinate is outside the Android display.' }
            $selectionResult = Invoke-BimAdb -Stage 'native_selection_tap' -Arguments ($deviceArgs + @('input', 'tap', [string][int]$bimSelection.x, [string][int]$bimSelection.y))
            if ($selectionResult.exit_code -ne 0) { throw 'Native selection tap failed.' }
            $bimSent.Add('selection') | Out-Null
            Write-Output "Native selection tap sent for PID $ViewerPid."
            return
        }

        if (-not $bimPointerDown -and $bimLog.Contains('BIM_SESSION_DIAGNOSTIC_RESULT')) {
            Write-Output 'Native cursor diagnostic finished; desktop pair was not verified.'
            return
        }
        Start-Sleep -Milliseconds 350
    }
    throw 'Timed out waiting for BIM native session input markers.'
} finally {
    if ($bimPointerDown -and $null -ne $bimCursor) {
        Invoke-BimAdb -Stage 'native_cursor_cleanup_up' -Arguments ($deviceArgs + @('input', 'touchscreen', 'motionevent', 'UP', [string][int]$bimCursor.move_x, [string][int]$bimCursor.move_y)) | Out-Null
    }
}
