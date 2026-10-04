param(
    [string]$GamePath = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid',
    [string]$Javac = 'C:\Users\ask13\.jdks\ms-21.0.8\bin\javac.exe',
    [string]$CartActionPath = 'C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3651954650\mods\SaucedCarts\42\media\lua\shared\SaucedCarts\TimedActions\ISCartTransferAction.lua'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$mod = Join-Path $repo 'Contents/mods/ActionTimeReducer/42'
$build = Join-Path $repo '.build'
New-Item -ItemType Directory -Path $build -Force | Out-Null
& $Javac -d $build (Join-Path $repo 'tests/LuaHarness.java')
if ($LASTEXITCODE -ne 0) { throw 'Harness compilation failed' }
$gameLua = Join-Path $GamePath 'media/lua/shared'
$core = Join-Path $mod 'media/lua/shared/ATR_Core.lua'
$coreSource = Get-Content -LiteralPath $core -Raw
$groupSource = $coreSource.Substring($coreSource.IndexOf('ATR.groups = {'))
$groupSource = $groupSource.Substring(0, $groupSource.IndexOf('local conflicts'))
$classNames = @([regex]::Matches($groupSource, '"(IS[A-Za-z0-9]+)"') | ForEach-Object { $_.Groups[1].Value })
$nativeLua = @(Get-ChildItem -LiteralPath (Join-Path $GamePath 'media/lua') -File -Recurse -Filter '*.lua')
$nativeActionPaths = foreach ($className in $classNames) {
    $matching = @($nativeLua | Where-Object { $_.BaseName -eq $className })
    if ($matching.Count -ne 1) { throw "Expected one native action file for $className; found $($matching.Count)" }
    $matching[0].FullName
}
$files = @(
    (Join-Path $repo 'tests/bootstrap.lua'),
    (Join-Path $gameLua 'ISBaseObject.lua'),
    (Join-Path $gameLua 'TimedActions/ISBaseTimedAction.lua')
) + @($nativeActionPaths) + @(
    (Join-Path $repo 'tests/before.lua'), $core,
    (Join-Path $mod 'media/lua/shared/ATR_Animals.lua'),
    (Join-Path $mod 'media/lua/shared/ATR_Chopping.lua'),
    (Join-Path $mod 'media/lua/shared/ATR_Liquids.lua'),
    (Join-Path $repo 'tests/actions.test.lua'),
    (Join-Path $repo 'tests/categories.test.lua'),
    (Join-Path $repo 'tests/chopping.test.lua'),
    (Join-Path $repo 'tests/liquids.test.lua'),
    (Join-Path $repo 'tests/live-settings.test.lua'),
    (Join-Path $repo 'tests/native-sp-actions.test.lua'), $core,
    (Join-Path $repo 'tests/reload.test.lua')
)
if (Test-Path -LiteralPath $CartActionPath) {
    # Read the user's installed dependency; never package third-party source.
    $files += @($CartActionPath, (Join-Path $repo 'tests/cart-transfer.test.lua'))
} else { Write-Output 'SKIP optional installed SaucedCarts action tests: dependency not found' }
Push-Location $GamePath
try {
    foreach ($mode in @('singleplayer', 'client', 'server')) {
        & (Join-Path $GamePath 'jre64/bin/java.exe') -cp "$build;$(Join-Path $GamePath 'projectzomboid.jar')" LuaHarness $mode @files
        if ($LASTEXITCODE -ne 0) { throw "Kahlua $mode tests failed" }
        $animalFixture = Join-Path $repo 'tests/animals.test.lua'
        & (Join-Path $GamePath 'jre64/bin/java.exe') -cp "$build;$(Join-Path $GamePath 'projectzomboid.jar')" LuaHarness $mode $animalFixture (Join-Path $mod 'media/lua/shared/ATR_Animals.lua') $animalFixture
        if ($LASTEXITCODE -ne 0) { throw "Kahlua $mode animal tests failed" }
    }
} finally { Pop-Location }
$en = Get-Content -LiteralPath (Join-Path $mod 'media/lua/shared/Translate/EN/Sandbox.json') -Raw | ConvertFrom-Json
$ko = Get-Content -LiteralPath (Join-Path $mod 'media/lua/shared/Translate/KO/Sandbox.json') -Raw | ConvertFrom-Json
if (Compare-Object @($en.PSObject.Properties.Name) @($ko.PSObject.Properties.Name)) { throw 'Translation key mismatch' }
$source = (Get-ChildItem -LiteralPath (Join-Path $mod 'media/lua/shared') -Filter 'ATR_*.lua' |
    ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
foreach ($forbidden in @('forceComplete', 'setActualWeight', 'setWeight', 'setTimeMultiplier')) {
    if ($source.Contains($forbidden)) { throw "Forbidden production operation: $forbidden" }
}
$nativeBase = Get-Content -LiteralPath (Join-Path $gameLua 'TimedActions/ISBaseTimedAction.lua') -Raw
foreach ($method in @('getDuration','create','adjustMaxTime','new')) {
    if ($nativeBase -notmatch "function ISBaseTimedAction:${method}\s*\(") { throw "Native contract missing: $method" }
}
$sandbox = Get-Content -LiteralPath (Join-Path $mod 'media/sandbox-options.txt') -Raw
$optionBlocks = [regex]::Matches($sandbox, '(?s)option ActionTimeReducer\.(\w+)\s*\{(.*?)\}')
$expectedOptions = @($classNames | ForEach-Object { if ($_ -eq 'ISInventoryTransferAction') { 'InventoryTransfer' } else { $_.Substring(2) } }) + @('Smoking', 'CartTransfer')
$actionBlocks = @($optionBlocks | Where-Object { $_.Groups[1].Value -notlike 'Section*' })
$sectionBlocks = @($optionBlocks | Where-Object { $_.Groups[1].Value -like 'Section*' })
if ($sectionBlocks.Count -ne 11) { throw 'Expected 11 checkbox dividers' }
$actualOptions = @($actionBlocks | ForEach-Object { $_.Groups[1].Value })
if (Compare-Object ($expectedOptions | Sort-Object) ($actualOptions | Sort-Object)) { throw 'Individual action option coverage mismatch' }
if (($actualOptions | Select-Object -Unique).Count -ne $actualOptions.Count) { throw 'Duplicate action option' }
foreach ($block in $optionBlocks) {
    if ($block.Groups[1].Value -like 'Section*') {
        if ($block.Groups[2].Value -notmatch 'type\s*=\s*boolean' -or
            $block.Groups[2].Value -notmatch 'default\s*=\s*false') { throw 'Invalid divider contract' }
    } elseif ($block.Groups[2].Value -notmatch 'type\s*=\s*integer' -or
        $block.Groups[2].Value -notmatch 'default\s*=\s*0' -or
        $block.Groups[2].Value -notmatch 'min\s*=\s*0' -or
        $block.Groups[2].Value -notmatch 'max\s*=\s*95') { throw 'Invalid numeric action contract' }
    $translationKey = 'Sandbox_ActionTimeReducer_' + $block.Groups[1].Value
    if (-not $en.PSObject.Properties[$translationKey] -or -not $ko.PSObject.Properties[$translationKey]) {
        throw "Missing action label: $translationKey"
    }
    $page = [regex]::Match($block.Groups[2].Value, 'page\s*=\s*(\w+)').Groups[1].Value
    if ($page -ne 'ActionTimeReducer') { throw 'All options must share one page' }
    foreach ($translations in @($en, $ko)) {
        if (-not $translations.PSObject.Properties['Sandbox_' + $page]) { throw "Missing page label: $page" }
        if (-not $translations.PSObject.Properties[$translationKey + '_tooltip']) { throw "Missing action tooltip: $translationKey" }
    }
}
$nodePath = Join-Path $mod 'media/AnimSets/player/actions/atr_chop_tree.xml'
[xml]$node = Get-Content -LiteralPath $nodePath -Raw
if ($node.animNode.m_Name -ne 'ATR_ChopTree' -or
    $node.animNode.m_SpeedScale -ne 'ATR_ChopTreeSpeed' -or
    $node.animNode.m_Conditions.m_Value -ne 'ATR_ChopTree' -or
    $node.animNode.m_Events.m_EventName -ne 'ChopTree') { throw 'Owned chopping animation contract mismatch' }
if ($source -match 'function\s+IS(?!BaseTimedAction)[A-Za-z]+[:.]new\s*\(') { throw 'Concrete constructor wrapped' }
Write-Output "PASS $($classNames.Count) native classes, $($actionBlocks.Count) independent zero-default options, 11 checkbox dividers on one page, EN/KO labels, owned animation XML and authority restrictions"
