param([Parameter(Mandatory)][string]$ServerRoot)
$ErrorActionPreference = 'Stop'
$resolvedRoot = (Resolve-Path -LiteralPath $ServerRoot).Path
$gameJar = Join-Path $resolvedRoot 'java/projectzomboid.jar'
if (-not (Test-Path -LiteralPath $gameJar)) { $gameJar = Join-Path $resolvedRoot 'projectzomboid.jar' }
if (-not (Test-Path -LiteralPath $gameJar)) { throw 'Dedicated server jar not found' }
$metadata = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'patch-manifest.json') -Raw | ConvertFrom-Json
$agent = Join-Path $PSScriptRoot 'ActionTimeReducer-server-agent.jar'
if ((Get-FileHash -LiteralPath $agent -Algorithm SHA256).Hash -ne $metadata.agentSha256) { throw 'Agent package hash mismatch' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($gameJar)
try {
    $entry = $archive.GetEntry('zombie/core/Transaction.class')
    if (-not $entry) { throw 'Transaction class missing' }
    $stream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
    try { $actualHash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
    finally { $stream.Dispose(); $sha.Dispose() }
} finally { $archive.Dispose() }
if ($actualHash -ne $metadata.targetClassSha256) { throw 'Unsupported server version or another Transaction patch; installation refused' }
$target = Join-Path $resolvedRoot 'ActionTimeReducer-server'
if (Test-Path -LiteralPath $target) { throw 'Existing patch folder preserved. Uninstall the old package before installing this version.' }
New-Item -ItemType Directory -Path $target | Out-Null
foreach ($file in @('ActionTimeReducer-server-agent.jar', 'patch-manifest.json', 'start-server.ps1', 'uninstall-server-patch.ps1', 'README.md')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $target $file)
}
Write-Output "Installed additive server patch at $target. Game jar and original launchers are unchanged."
