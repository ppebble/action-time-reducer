$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$stage = Join-Path $repo '.stage/action-time-reducer-server-patch'
$fixture = Join-Path $repo ('.build/action-time-reducer/server-patch/install-test-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $fixture 'java') -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$gameJar = 'C:\Program Files (x86)\Steam\steamapps\common\Project Zomboid Dedicated Server\java\projectzomboid.jar'
$source = [IO.Compression.ZipFile]::OpenRead($gameJar)
$fixtureJar = Join-Path $fixture 'java/projectzomboid.jar'
$copy = [IO.Compression.ZipFile]::Open($fixtureJar, [IO.Compression.ZipArchiveMode]::Create)
try {
    $read = $source.GetEntry('zombie/core/Transaction.class').Open()
    $write = $copy.CreateEntry('zombie/core/Transaction.class').Open()
    try { $read.CopyTo($write) } finally { $read.Dispose(); $write.Dispose() }
} finally { $source.Dispose(); $copy.Dispose() }
$beforeHash = (Get-FileHash -LiteralPath $fixtureJar).Hash
& (Join-Path $stage 'install-server-patch.ps1') -ServerRoot $fixture
$installed = Join-Path $fixture 'ActionTimeReducer-server'
$duplicateRefused = $false
try { & (Join-Path $stage 'install-server-patch.ps1') -ServerRoot $fixture } catch { $duplicateRefused = $true }
if (-not $duplicateRefused) { throw 'Duplicate installation was not refused' }
$launcher = Join-Path $fixture 'launcher-test.ps1'
[IO.File]::WriteAllText($launcher, 'param([string]$Example) if ($env:JAVA_TOOL_OPTIONS -notmatch "-javaagent:") { throw "Missing agent" }; if ($Example -ne "preserved") { throw "Arguments changed" }; $global:LASTEXITCODE = 0', [Text.UTF8Encoding]::new($false))
$savedOptions = $env:JAVA_TOOL_OPTIONS
& (Join-Path $installed 'start-server.ps1') -Launcher 'launcher-test.ps1' -ServerArguments @('preserved')
if ($env:JAVA_TOOL_OPTIONS -ne $savedOptions) { throw 'Process environment not restored' }
if ((Get-FileHash -LiteralPath $fixtureJar).Hash -ne $beforeHash) { throw 'Original jar changed' }
$unknown = Join-Path $installed 'user-file.txt'
[IO.File]::WriteAllText($unknown, 'preserve')
$uninstallRefused = $false
try { & (Join-Path $installed 'uninstall-server-patch.ps1') } catch { $uninstallRefused = $true }
if (-not $uninstallRefused -or -not (Test-Path -LiteralPath $unknown)) { throw 'Unknown user file was not preserved' }
Remove-Item -LiteralPath $unknown
& (Join-Path $installed 'uninstall-server-patch.ps1')
if (Test-Path -LiteralPath $installed) { throw 'Owned patch folder remains' }
if ((Get-FileHash -LiteralPath $fixtureJar).Hash -ne $beforeHash -or -not (Test-Path -LiteralPath $launcher)) { throw 'Original server files were removed' }
Write-Output 'PASS additive install, duplicate refusal, launcher/arguments/environment preservation, guarded uninstall, original server jar unchanged'
