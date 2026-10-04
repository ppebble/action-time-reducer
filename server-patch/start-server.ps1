param(
    [string]$Launcher = 'StartServer64.bat',
    [string[]]$ServerArguments = @()
)
$ErrorActionPreference = 'Stop'
$serverRoot = Split-Path $PSScriptRoot -Parent
$launcherPath = if ([IO.Path]::IsPathRooted($Launcher)) { $Launcher } else { Join-Path $serverRoot $Launcher }
if (-not (Test-Path -LiteralPath $launcherPath)) { throw 'Original server launcher not found' }
$agent = Join-Path $PSScriptRoot 'ActionTimeReducer-server-agent.jar'
$metadata = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'patch-manifest.json') -Raw | ConvertFrom-Json
if ((Get-FileHash -LiteralPath $agent -Algorithm SHA256).Hash -ne $metadata.agentSha256) { throw 'Agent hash mismatch' }
$savedOptions = $env:JAVA_TOOL_OPTIONS
if ($savedOptions -match 'ActionTimeReducer-server-agent') { throw 'Duplicate server agent in JAVA_TOOL_OPTIONS' }
try {
    # Process-local: the original launcher keeps its memory, native library and
    # server settings. Neither the launcher nor machine-wide variables are edited.
    $env:JAVA_TOOL_OPTIONS = ($savedOptions + ' "-javaagent:' + $agent + '"').Trim()
    Push-Location $serverRoot
    try { & $launcherPath @ServerArguments; $serverExitCode = $LASTEXITCODE }
    finally { Pop-Location }
} finally {
    if ($null -eq $savedOptions) { Remove-Item Env:JAVA_TOOL_OPTIONS -ErrorAction SilentlyContinue }
    else { $env:JAVA_TOOL_OPTIONS = $savedOptions }
}
exit $serverExitCode
