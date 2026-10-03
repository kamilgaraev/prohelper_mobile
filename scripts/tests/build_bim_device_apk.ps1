param(
    [Parameter(Mandatory = $true)]
    [string] $Target,
    [Parameter(Mandatory = $true)]
    [string] $DefinesPath,
    [Parameter(Mandatory = $true)]
    [string] $OutputPath,
    [switch] $Offline
)

$ErrorActionPreference = 'Stop'
$bimRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$bimApp = (Join-Path $bimRoot 'android/app').Replace('\', '/')
$bimAndroidRoot = (Join-Path $bimRoot 'android').Replace('\', '/')
$bimOfflineDependencies = if ($Offline) {
    @"
    if (project.rootProject.projectDir.canonicalFile == new File('$bimAndroidRoot').canonicalFile) {
        project.configurations.configureEach {
            resolutionStrategy.force 'androidx.test:runner:1.3.0', 'androidx.test:rules:1.2.0', 'androidx.test.espresso:espresso-core:3.3.0'
        }
    }
"@
} else { '' }
$bimInitPath = Join-Path ([IO.Path]::GetTempPath()) 'most-bim-acceptance.init.gradle'
$bimInit = @"
gradle.beforeProject { project ->
$bimOfflineDependencies
    def allowedApp = new File('$bimApp').canonicalFile
    if (project.projectDir.canonicalFile == allowedApp) {
        project.plugins.withId('com.android.application') {
            project.extensions.getByName('androidComponents').finalizeDsl { dsl ->
                dsl.defaultConfig.applicationIdSuffix = '.bimacceptance'
            }
        }
    }
}
"@
[IO.File]::WriteAllText($bimInitPath, $bimInit, [Text.UTF8Encoding]::new($false))
$bimDefines = Get-Content -LiteralPath $DefinesPath -Raw | ConvertFrom-Json -AsHashtable
if ($bimDefines.Keys | Where-Object { $_ -match '(?i)token|jwt' }) {
    throw 'Use BIM_API_CONFIG_URL; do not pass JWT to the test compiler.'
}
$bimEncoded = (($bimDefines.GetEnumerator() | ForEach-Object {
    [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($_.Key)=$($_.Value)"))
}) -join ',')
$bimPreviousJavaHome = $env:JAVA_HOME
$bimPreviousJavaOptions = $env:JAVA_TOOL_OPTIONS
try {
    $env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
    $env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir=C:/__most_bim_no_unix_socket__'
    Push-Location (Join-Path $bimRoot 'android')
    try {
        $bimGradleOptions = @('--console=plain')
        if ($Offline) { $bimGradleOptions += '--offline' }
        & ./gradlew.bat @bimGradleOptions --init-script $bimInitPath :app:assembleDebug '-Ptarget-platform=android-x64' "-Ptarget=$Target" '-Pbase-application-name=android.app.Application' "-Pdart-defines=$bimEncoded" '-Pdart-obfuscation=false' '-Ptrack-widget-creation=true' '-Ptree-shake-icons=false'
        if ($LASTEXITCODE -ne 0) { throw "Gradle failed: $LASTEXITCODE" }
    } finally {
        Pop-Location
    }
    $bimApk = Join-Path $bimRoot 'build/app/outputs/apk/debug/app-debug.apk'
    $bimBuildTools = 'C:/Users/kamilgaraev/AppData/Local/Android/sdk/build-tools/36.0.0'
    $bimMetadata = & (Join-Path $bimBuildTools 'aapt.exe') dump badging $bimApk
    if ($LASTEXITCODE -ne 0 -or $bimMetadata[0] -notmatch "package: name='ru.prohelper.prohelpers_mobile.bimacceptance'") {
        throw 'APK package is not isolated; installation is forbidden.'
    }
    $bimMetadata | Select-String '^(package:|launchable-activity:|application-debuggable)'
    & (Join-Path $bimBuildTools 'apksigner.bat') verify --print-certs $bimApk
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
    Copy-Item -LiteralPath $bimApk -Destination ([IO.Path]::GetFullPath($OutputPath))
    Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256
} finally {
    $env:JAVA_HOME = $bimPreviousJavaHome
    $env:JAVA_TOOL_OPTIONS = $bimPreviousJavaOptions
}
