param(
    [string]$GamePath = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid',
    [string]$DedicatedPath = 'C:\Program Files (x86)\Steam\steamapps\common\Project Zomboid Dedicated Server',
    [string]$JdkPath = 'C:\Users\ask13\.jdks\ms-21.0.8',
    [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (-not $SkipBuild) {
    & (Join-Path $PSScriptRoot 'build-manual-server-patch.ps1') -GamePath $GamePath -JdkPath $JdkPath
}
$production = Join-Path $repo '.build/action-time-reducer/manual-server-patch/classes'
$tests = Join-Path $repo '.build/action-time-reducer/server-patch/test-classes'
$overlay = Join-Path $repo 'Contents/mods/ActionTimeReducer/common/ServerPatch/classes'
$patched = Join-Path $overlay 'zombie/core/Transaction.class'
if (-not (Test-Path -LiteralPath $patched)) { throw 'Build the manual class-copy package before testing' }
$expectedFiles = @('actiontimereducer/server/TransferDuration.class', 'actiontimereducer/server/TransferDuration$Access.class', 'zombie/core/Transaction.class')
$actualFiles = @(Get-ChildItem -LiteralPath $overlay -Recurse -File | ForEach-Object { $_.FullName.Substring($overlay.Length + 1).Replace('\', '/') } | Sort-Object)
if (($actualFiles -join '|') -ne (($expectedFiles | Sort-Object) -join '|')) { throw "Manual overlay contains unexpected files: $($actualFiles -join ', ')" }
New-Item -ItemType Directory -Path $tests -Force | Out-Null
$sources = @(Get-ChildItem -LiteralPath (Join-Path $repo 'server-patch/tests') -Filter '*.java' -File -Recurse | ForEach-Object FullName)
& (Join-Path $JdkPath 'bin/javac.exe') -source 17 -target 17 --add-exports java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED -cp $production -d $tests @sources
if ($LASTEXITCODE -ne 0) { throw 'Manual-copy audit compilation failed' }
$clientJar = Join-Path $GamePath 'projectzomboid.jar'
if (-not (Test-Path -LiteralPath $clientJar)) { $clientJar = Join-Path $GamePath 'java/projectzomboid.jar' }
& (Join-Path $JdkPath 'bin/java.exe') --add-exports java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED -cp "$production;$tests" actiontimereducer.server.PatchAudit $clientJar $patched
if ($LASTEXITCODE -ne 0) { throw 'Manual-copy bytecode or settings audit failed' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$supportedHash = '107B0A554CC46D1015398FF283A2E48FAF02EFBC44ADF12854F66394EE2487B6'
foreach ($installation in @($GamePath, $DedicatedPath)) {
    $gameJar = Join-Path $installation 'projectzomboid.jar'
    if (-not (Test-Path -LiteralPath $gameJar)) { $gameJar = Join-Path $installation 'java/projectzomboid.jar' }
    $runtime = Join-Path $installation 'jre64/bin/java.exe'
    if (-not (Test-Path -LiteralPath $gameJar) -or -not (Test-Path -LiteralPath $runtime)) { throw "Missing native test installation: $installation" }
    $jarArchive = [System.IO.Compression.ZipFile]::OpenRead($gameJar)
    try {
        $nativeClass = $jarArchive.GetEntry('zombie/core/Transaction.class')
        if ($null -eq $nativeClass) { throw "Original Transaction class missing: $installation" }
        $stream = $nativeClass.Open()
        $hasher = [System.Security.Cryptography.SHA256]::Create()
        try {
            $originalHash = [BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-', '')
        } finally { $stream.Dispose(); $hasher.Dispose() }
        if ($originalHash -ne $supportedHash) { throw "Unsupported native Transaction fingerprint: $installation ($originalHash)" }
    } finally { $jarArchive.Dispose() }
    & $runtime -Xverify:all -cp "$overlay;$tests;$gameJar" actiontimereducer.server.ManualClassLoadSmoke $overlay overlay --child
    if ($LASTEXITCODE -ne 0) { throw "Native manual-copy class loading failed: $installation" }
    & $runtime -Xverify:all -cp "$tests;$gameJar" actiontimereducer.server.ManualClassLoadSmoke $gameJar vanilla
    if ($LASTEXITCODE -ne 0) { throw "Native vanilla restoration class loading failed: $installation" }
}
Write-Output 'PASS manual package has only three required classes; bytecode/settings audit and client/dedicated native JVM overlay, child-process and vanilla probes passed.'
Write-Output 'LIMITATION: no actual server boot, in-game host, connected client, transfer/cancel gameplay or performance proof.'
