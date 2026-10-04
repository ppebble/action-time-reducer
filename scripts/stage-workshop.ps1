param([string]$DestinationRoot = 'C:\Users\ask13\Zomboid\Workshop')
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$source = Join-Path $repo 'Contents'
$destination = Join-Path ([IO.Path]::GetFullPath($DestinationRoot)) 'ActionTimeReducer'
$description = Join-Path $repo 'docs/workshop-description-en.bbcode'
$preview = Join-Path $repo 'workshop/preview.png'
foreach ($path in @($source, $description, $preview)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing upload source: $path" }
}
$existingMetadata = Join-Path $destination 'workshop.txt'
if (Test-Path -LiteralPath $existingMetadata) {
    throw 'Existing Workshop staging preserved; choose a new DestinationRoot to refresh.'
}
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Copy-Item -LiteralPath $source -Destination (Join-Path $destination 'Contents') -Recurse
Copy-Item -LiteralPath $preview -Destination (Join-Path $destination 'preview.png')
$metadata = @('version=1', 'title=Action Time Reducer [B42.21]')
$metadata += @(Get-Content -LiteralPath $description | ForEach-Object { 'description=' + $_ })
$metadata += @('tags=Build 42;Balance', 'visibility=private')
[IO.File]::WriteAllLines($existingMetadata, $metadata, [Text.UTF8Encoding]::new($false))
$staged = Join-Path $destination 'Contents'
$expected = @(Get-ChildItem -LiteralPath $source -Recurse -File -Force)
$actual = @(Get-ChildItem -LiteralPath $staged -Recurse -File -Force)
if ($expected.Count -ne $actual.Count) { throw 'Workshop file count mismatch' }
foreach ($file in $expected) {
    $relative = [IO.Path]::GetRelativePath($source, $file.FullName)
    if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne
        (Get-FileHash -LiteralPath (Join-Path $staged $relative)).Hash) { throw "Workshop hash mismatch: $relative" }
}
Write-Output "PASS Workshop staging: $($expected.Count) content files match SHA-256 at $destination"
& (Join-Path $PSScriptRoot 'test-workshop-package.ps1') -WorkshopFolder $destination
Write-Output 'Prepared private metadata only; no Steam upload performed.'
