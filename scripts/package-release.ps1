$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$version = '0.5.1'
& (Join-Path $PSScriptRoot 'build-manual-server-patch.ps1')
$release = Join-Path $repo ".stage/$version"
New-Item -ItemType Directory -Path $release -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repo 'Contents') -Destination $release -Recurse -Force
Copy-Item -LiteralPath (Join-Path $repo 'README.md') -Destination $release -Force
Copy-Item -LiteralPath (Join-Path $repo 'docs') -Destination $release -Recurse -Force
$source = Join-Path $repo 'Contents'
$copy = Join-Path $release 'Contents'
$expected = @(Get-ChildItem -LiteralPath $source -File -Recurse)
if (@(Get-ChildItem -LiteralPath $copy -File -Recurse).Count -ne $expected.Count) { throw 'Staged mod file count mismatch' }
foreach ($file in $expected) {
    $relative = [IO.Path]::GetRelativePath($source, $file.FullName)
    if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath (Join-Path $copy $relative)).Hash) { throw "Stage hash mismatch: $relative" }
}
Compress-Archive -Path (Join-Path $release '*') -DestinationPath (Join-Path $repo ".stage/ActionTimeReducer-$version.zip") -Force
Compress-Archive -Path (Join-Path $repo 'Contents/mods/ActionTimeReducer/common/ServerPatch/*') -DestinationPath (Join-Path $repo ".stage/ActionTimeReducer-server-classes-$version.zip") -Force
$package = Join-Path $repo 'Contents/mods/ActionTimeReducer/common/ServerPatch'
$metadata = Get-Content -LiteralPath (Join-Path $package 'patch-manifest.json') -Raw | ConvertFrom-Json
if ($metadata.version -ne '0.4.2' -or $metadata.mode -ne 'manual-class-override' -or $metadata.files.Count -ne 3) { throw 'Manual patch metadata mismatch' }
foreach ($entry in $metadata.files) {
    if ((Get-FileHash -LiteralPath (Join-Path $package "classes/$($entry.path)")).Hash -ne $entry.sha256) { throw 'Manual class package hash mismatch' }
}
$allowed = @('classes/zombie/core/Transaction.class', 'classes/actiontimereducer/server/TransferDuration.class', 'classes/actiontimereducer/server/TransferDuration$Access.class', 'README.md', 'patch-manifest.json')
$actual = @(Get-ChildItem -LiteralPath $package -File -Recurse | ForEach-Object { [IO.Path]::GetRelativePath($package, $_.FullName).Replace('\', '/') })
if ((($actual | Sort-Object) -join '|') -ne (($allowed | Sort-Object) -join '|')) { throw 'Manual package contains unexpected files' }
Write-Output "PASS manual release packages: $($expected.Count) staged files match SHA-256; only three class files, instructions and metadata in ServerPatch"
