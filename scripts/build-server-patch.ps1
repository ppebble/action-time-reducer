param(
    [string]$GamePath = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid',
    [string]$JdkPath = 'C:\Users\ask13\.jdks\ms-21.0.8'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$gameJar = Join-Path $GamePath 'projectzomboid.jar'
if (-not (Test-Path -LiteralPath $gameJar)) { $gameJar = Join-Path $GamePath 'java/projectzomboid.jar' }
if (-not (Test-Path -LiteralPath $gameJar)) { throw 'Game jar not found' }
$classes = Join-Path $repo '.build/action-time-reducer/server-patch/classes-classfile'
$stage = Join-Path $repo '.stage/action-time-reducer-server-patch'
New-Item -ItemType Directory -Path $classes, $stage -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($gameJar)
try {
    $entry = $archive.GetEntry('zombie/core/Transaction.class')
    if (-not $entry) { throw 'Native Transaction class missing' }
    $stream = $entry.Open()
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $classHash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
    finally { $stream.Dispose(); $sha.Dispose() }
} finally { $archive.Dispose() }
[IO.File]::WriteAllText((Join-Path $classes 'supported-class.sha256'), $classHash + "`n", [Text.UTF8Encoding]::new($false))
$sources = @(Get-ChildItem -LiteralPath (Join-Path $repo 'server-patch/src') -File -Recurse -Filter '*.java' | ForEach-Object FullName)
& (Join-Path $JdkPath 'bin/javac.exe') --release 17 -d $classes @sources
if ($LASTEXITCODE -ne 0) { throw 'Server agent compilation failed' }
$manifestPath = Join-Path $repo '.build/action-time-reducer/server-patch/MANIFEST.MF'
[IO.File]::WriteAllText($manifestPath, "Manifest-Version: 1.0`nPremain-Class: actiontimereducer.server.Agent`nCan-Redefine-Classes: false`nCan-Retransform-Classes: false`n`n", [Text.UTF8Encoding]::new($false))
$agentJar = Join-Path $stage 'ActionTimeReducer-server-agent.jar'
& (Join-Path $JdkPath 'bin/jar.exe') --create --file $agentJar --manifest $manifestPath -C $classes actiontimereducer -C $classes supported-class.sha256
if ($LASTEXITCODE -ne 0) { throw 'Server agent packaging failed' }
$packageMetadata = @{
    version = '0.4.2'; targetClass = 'zombie/core/Transaction.class'; targetClassSha256 = $classHash
    agentSha256 = (Get-FileHash -LiteralPath $agentJar -Algorithm SHA256).Hash
}
$packageMetadata | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stage 'patch-manifest.json') -Encoding utf8
foreach ($file in @('install-server-patch.ps1', 'start-server.ps1', 'uninstall-server-patch.ps1')) {
    Copy-Item -LiteralPath (Join-Path $repo "server-patch/$file") -Destination (Join-Path $stage $file) -Force
}
Copy-Item -LiteralPath (Join-Path $repo 'server-patch/README.md') -Destination (Join-Path $stage 'README.md') -Force
Write-Output "PASS server agent built for Transaction SHA256 $classHash"
