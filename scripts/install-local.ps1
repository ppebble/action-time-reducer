param(
    [string]$ModsRoot = 'C:\Users\ask13\Zomboid\mods',
    [switch]$VerifyOnly
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$source = Join-Path $repo 'Contents/mods/ActionTimeReducer'
$target = Join-Path ([IO.Path]::GetFullPath($ModsRoot)) 'ActionTimeReducer'
if (-not $VerifyOnly) {
    if (Test-Path -LiteralPath $target) { throw "Existing install preserved; use -VerifyOnly: $target" }
    New-Item -ItemType Directory -Path $ModsRoot -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $target -Recurse
}
if (-not (Test-Path -LiteralPath $target)) { throw 'Install missing' }
$expected = @(Get-ChildItem -LiteralPath $source -File -Recurse -Force)
$actual = @(Get-ChildItem -LiteralPath $target -File -Recurse -Force)
if ($actual.Count -ne $expected.Count) { throw 'Installed file count mismatch' }
foreach ($file in $expected) {
    $relative = [IO.Path]::GetRelativePath($source, $file.FullName)
    $installed = Join-Path $target $relative
    if (-not (Test-Path -LiteralPath $installed)) { throw "Installed file missing: $relative" }
    if ((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne
        (Get-FileHash -LiteralPath $installed -Algorithm SHA256).Hash) {
        throw "Installed hash mismatch: $relative"
    }
}
Write-Output "PASS local install: $($expected.Count) files match SHA-256 at $target"
