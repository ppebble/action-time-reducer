param(
    [string]$GamePath = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid',
    [string]$JdkPath = 'C:\Users\ask13\.jdks\ms-21.0.8'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
& (Join-Path $PSScriptRoot 'build-server-patch.ps1') -GamePath $GamePath -JdkPath $JdkPath
$gameJar = Join-Path $GamePath 'projectzomboid.jar'
if (-not (Test-Path -LiteralPath $gameJar)) { $gameJar = Join-Path $GamePath 'java/projectzomboid.jar' }
$runtime = Join-Path $GamePath 'jre64/bin/java.exe'
$classes = Join-Path $repo '.build/action-time-reducer/server-patch/classes-classfile'
$tests = Join-Path $repo '.build/action-time-reducer/server-patch/test-classes'
New-Item -ItemType Directory -Path $tests -Force | Out-Null
$sources = @(Get-ChildItem -LiteralPath (Join-Path $repo 'server-patch/tests') -Filter '*.java' -File -Recurse | ForEach-Object FullName)
# The audit-only parser uses JDK21 ASM on a copy with a normalized class header.
# Production transformation and agent loading use the unmodified shipped Java25.
& (Join-Path $JdkPath 'bin/javac.exe') -source 17 -target 17 --add-exports java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED -cp $classes -d $tests @sources
if ($LASTEXITCODE -ne 0) { throw 'Audit compilation failed' }
$auditClass = Join-Path $repo '.build/action-time-reducer/server-patch/Transaction-audit.class'
& $runtime -cp "$classes;$tests" actiontimereducer.server.EmitTransformedAudit $gameJar $auditClass
if ($LASTEXITCODE -ne 0) { throw 'Shipped runtime transformation failed' }
& (Join-Path $JdkPath 'bin/java.exe') --add-exports java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED -cp "$classes;$tests" actiontimereducer.server.PatchAudit $gameJar $auditClass
if ($LASTEXITCODE -ne 0) { throw 'Bytecode or settings audit failed' }
$agent = Join-Path $repo '.stage/action-time-reducer-server-patch/ActionTimeReducer-server-agent.jar'
& $runtime -Xverify:all "-javaagent:$agent" -cp "$tests;$gameJar" actiontimereducer.server.AgentLoadSmoke
if ($LASTEXITCODE -ne 0) { throw 'Actual JVM agent load failed' }
& (Join-Path $PSScriptRoot 'test-server-package.ps1')
