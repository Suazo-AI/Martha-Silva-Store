# Installs a pinned upstream release for this Windows user. Does not register a
# repository, start a daemon, change PATH or Git configuration, or call an agent.
[CmdletBinding()]
param(
    [string]$ArchivePath,
    [string]$InstallRoot
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
if ($env:OS -ne 'Windows_NT') { throw 'This installer is for Windows only.' }
$version = 'v1.106.1'
$expected = @{
    amd64 = '78e17f98e9d9448368ce126f34101f01ca43f55d5797e3f55f5e11aadd175bef'
    arm64 = '69a95132ae0140e8d15878657e9bc3ba9c555d9aa49b37c640f5115fb67af5a8'
}
$native = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
if ($native -eq 'AMD64') { $arch = 'amd64' } elseif ($native -eq 'ARM64') { $arch = 'arm64' } else { throw "Unsupported Windows architecture: $native" }
if (-not $InstallRoot) { $InstallRoot = Join-Path $env:LOCALAPPDATA 'Programs\no-mistakes' }
$targetDir = Join-Path (Join-Path $InstallRoot $version) $arch
$target = Join-Path $targetDir 'no-mistakes.exe'
$scratch = Join-Path ([IO.Path]::GetTempPath()) ("nm-install-" + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($scratch)
$settings = @{}
foreach ($key in @('NM_HOME', 'NO_MISTAKES_TELEMETRY', 'NO_MISTAKES_NO_UPDATE_CHECK')) {
    $settings[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
}
try {
    if (-not $ArchivePath) {
        $name = "no-mistakes-$version-windows-$arch.zip"
        $ArchivePath = Join-Path $scratch $name
        $source = "https://github.com/kunchenguid/no-mistakes/releases/download/$version/$name"
        Invoke-WebRequest -UseBasicParsing -Uri $source -OutFile $ArchivePath
    }
    $file = (Get-Item -LiteralPath $ArchivePath).FullName
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $expected[$arch]) { throw 'Release ZIP SHA256 mismatch; installation stopped.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($file)
    $candidate = Join-Path $scratch 'no-mistakes.exe'
    try {
        if ($zip.Entries.Count -ne 1 -or $zip.Entries[0].FullName -cne 'no-mistakes.exe') { throw 'Unexpected official ZIP layout.' }
        [IO.Compression.ZipFileExtensions]::ExtractToFile($zip.Entries[0], $candidate, $false)
    } finally { $zip.Dispose() }
    $env:NM_HOME = Join-Path $scratch 'nm-home'
    $env:NO_MISTAKES_TELEMETRY = 'off'
    $env:NO_MISTAKES_NO_UPDATE_CHECK = '1'
    $info = (& $candidate --version | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $info -notmatch '^no-mistakes version v1\.106\.1 \(5732d1e\)') { throw 'Unexpected executable version or commit; installation stopped.' }
    $hash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash
    [void][IO.Directory]::CreateDirectory($targetDir)
    if (Test-Path -LiteralPath $target) {
        if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $hash) { throw "Existing executable differs. Refusing to overwrite: $target" }
    } else {
        [IO.File]::Copy($candidate, $target, $false)
    }
    if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $hash) { throw 'Installed executable SHA256 mismatch.' }
    [PSCustomObject]@{ Executable = $target; Version = $info; ArchiveSHA256 = $expected[$arch]; ExecutableSHA256 = $hash }
} finally {
    foreach ($key in $settings.Keys) { [Environment]::SetEnvironmentVariable($key, $settings[$key], 'Process') }
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
