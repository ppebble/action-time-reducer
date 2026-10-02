param(
    [string]$GamePath = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid',
    [string]$Javac = 'C:\Users\ask13\.jdks\ms-21.0.8\bin\javac.exe'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$mod = Join-Path $repo 'Contents/mods/SafeActionTime/42'
$build = Join-Path $repo '.build'
New-Item -ItemType Directory -Path $build -Force | Out-Null
& $Javac -d $build (Join-Path $repo 'tests/LuaHarness.java')
if ($LASTEXITCODE -ne 0) { throw 'Harness compilation failed' }
$gameLua = Join-Path $GamePath 'media/lua/shared'
$core = Join-Path $mod 'media/lua/shared/SAT_Core.lua'
$files = @(
    (Join-Path $repo 'tests/bootstrap.lua'),
    (Join-Path $gameLua 'ISBaseObject.lua'),
    (Join-Path $gameLua 'TimedActions/ISBaseTimedAction.lua'),
    (Join-Path $gameLua 'TimedActions/ISCraftAction.lua'),
    (Join-Path $gameLua 'Entity/TimedActions/ISHandcraftAction.lua'),
    (Join-Path $gameLua 'TimedActions/ISDismantleAction.lua'),
    (Join-Path $repo 'tests/before.lua'), $core,
    (Join-Path $repo 'tests/actions.test.lua'), $core,
    (Join-Path $repo 'tests/reload.test.lua')
)
Push-Location $GamePath
try {
    foreach ($mode in @('singleplayer', 'client', 'server')) {
        & (Join-Path $GamePath 'jre64/bin/java.exe') -cp "$build;$(Join-Path $GamePath 'projectzomboid.jar')" LuaHarness $mode @files
        if ($LASTEXITCODE -ne 0) { throw "Kahlua $mode tests failed" }
    }
} finally { Pop-Location }
$en = Get-Content -LiteralPath (Join-Path $mod 'media/lua/shared/Translate/EN/Sandbox.json') -Raw | ConvertFrom-Json
$ko = Get-Content -LiteralPath (Join-Path $mod 'media/lua/shared/Translate/KO/Sandbox.json') -Raw | ConvertFrom-Json
if (Compare-Object @($en.PSObject.Properties.Name) @($ko.PSObject.Properties.Name)) { throw 'Translation key mismatch' }
$source = Get-Content -LiteralPath $core -Raw
foreach ($forbidden in @('forceComplete', 'setActualWeight', 'setWeight', 'setTimeMultiplier')) {
    if ($source.Contains($forbidden)) { throw "Forbidden production operation: $forbidden" }
}
$nativeBase = Get-Content -LiteralPath (Join-Path $gameLua 'TimedActions/ISBaseTimedAction.lua') -Raw
foreach ($method in @('getDuration','create','adjustMaxTime','new')) {
    if ($nativeBase -notmatch "function ISBaseTimedAction:${method}\s*\(") { throw "Native contract missing: $method" }
}
Write-Output 'PASS EN/KO keys, production operation restrictions, native Lua contracts'
