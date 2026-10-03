param(
    [Parameter(Mandatory = $true)]
    [string] $FixturePath,
    [Parameter(Mandatory = $true)]
    [string] $FixtureUrl,
    [string] $OutputPath = (Join-Path ([System.IO.Path]::GetTempPath()) 'most-bim-device-defines.json'),
    [switch] $RequirePlatformLifecycle,
    [switch] $ExternalTouch
)

$ErrorActionPreference = 'Stop'
$fixture = (Resolve-Path -LiteralPath $FixturePath).Path
$bytes = [System.IO.File]::ReadAllBytes($fixture)
$defines = @{
    BIM_FIXTURE_URL = $FixtureUrl
    BIM_DEVICE_FRAG_SHA256 = (Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash.ToLowerInvariant()
    BIM_DEVICE_REQUIRE_PLATFORM_LIFECYCLE = $RequirePlatformLifecycle.IsPresent.ToString().ToLowerInvariant()
    BIM_DEVICE_EXTERNAL_TOUCH = $ExternalTouch.IsPresent.ToString().ToLowerInvariant()
}
$output = [System.IO.Path]::GetFullPath($OutputPath)
[System.IO.File]::WriteAllText($output, ($defines | ConvertTo-Json -Compress), [System.Text.UTF8Encoding]::new($false))
Write-Output "BIM test defines: $output; fixture bytes: $($bytes.Length)"
