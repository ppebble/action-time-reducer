param(
    [string]$GamePath = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid',
    [string]$JdkPath = 'C:\Users\ask13\.jdks\ms-21.0.8'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$gameJar = Join-Path $GamePath 'projectzomboid.jar'
if (-not (Test-Path -LiteralPath $gameJar)) { $gameJar = Join-Path $GamePath 'java/projectzomboid.jar' }
if (-not (Test-Path -LiteralPath $gameJar)) { throw 'Game jar not found' }
$build = Join-Path $repo '.build/action-time-reducer/manual-server-patch/classes'
$package = Join-Path $repo 'Contents/mods/ActionTimeReducer/common/ServerPatch'
$files = Join-Path $package 'classes'
New-Item -ItemType Directory -Path $build, $files -Force | Out-Null
$sources = @(Get-ChildItem -LiteralPath (Join-Path $repo 'server-patch/src') -Filter '*.java' -File -Recurse | ForEach-Object FullName)
$sources += Join-Path $repo 'server-patch/tools/actiontimereducer/server/BuildManualPatch.java'
& (Join-Path $JdkPath 'bin/javac.exe') --release 17 -d $build @sources
if ($LASTEXITCODE -ne 0) { throw 'Manual patch build compilation failed' }
$patchedClass = Join-Path $files 'zombie/core/Transaction.class'
& (Join-Path $GamePath 'jre64/bin/java.exe') -cp "$build;$gameJar" actiontimereducer.server.BuildManualPatch $gameJar $patchedClass
if ($LASTEXITCODE -ne 0) { throw 'Pinned original class did not match or transformation failed' }
$helperDir = Join-Path $files 'actiontimereducer/server'
New-Item -ItemType Directory -Path $helperDir -Force | Out-Null
foreach ($name in @('TransferDuration.class', 'TransferDuration$Access.class')) {
    Copy-Item -LiteralPath (Join-Path $build "actiontimereducer/server/$name") -Destination (Join-Path $helperDir $name) -Force
}
$expected = @('zombie/core/Transaction.class', 'actiontimereducer/server/TransferDuration.class', 'actiontimereducer/server/TransferDuration$Access.class')
$actual = @(Get-ChildItem -LiteralPath $files -File -Recurse)
if ($actual.Count -ne $expected.Count) { throw 'Unexpected manual package files; preserve and inspect them before rebuilding' }
$hashes = foreach ($name in $expected) {
    @{ path = $name; sha256 = (Get-FileHash -LiteralPath (Join-Path $files $name) -Algorithm SHA256).Hash }
}
$metadata = @{
    version = '0.4.2'; gameVersion = '42.21'; mode = 'manual-class-override'
    sourceClassSha256 = '107B0A554CC46D1015398FF283A2E48FAF02EFBC44ADF12854F66394EE2487B6'
    files = @($hashes)
    dedicatedCopyTarget = '<dedicated-server-install>/java'
    hostCopyTarget = '<ProjectZomboid-install>'
    hostGameplayVerified = $false; twoClientGameplayVerified = $false
}
$utf8 = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText((Join-Path $package 'patch-manifest.json'), ($metadata | ConvertTo-Json -Depth 5) + "`n", $utf8)
Copy-Item -LiteralPath (Join-Path $repo 'server-patch/manual-README.md') -Destination (Join-Path $package 'README.md') -Force
Write-Output 'PASS manual copy package: exactly one modified game class and two owned helper classes; no installer or agent required'
