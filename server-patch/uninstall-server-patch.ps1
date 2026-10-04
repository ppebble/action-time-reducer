$ErrorActionPreference = 'Stop'
$target = [IO.Path]::GetFullPath($PSScriptRoot)
if ((Split-Path $target -Leaf) -ne 'ActionTimeReducer-server') { throw 'Run the installed uninstaller inside ActionTimeReducer-server' }
$files = @('ActionTimeReducer-server-agent.jar', 'patch-manifest.json', 'start-server.ps1', 'uninstall-server-patch.ps1', 'README.md')
$unexpected = @(Get-ChildItem -LiteralPath $target -Force | Where-Object { $_.PSIsContainer -or $_.Name -notin $files })
if ($unexpected.Count -gt 0) { throw 'Unrecognised files preserved; uninstall stopped' }
foreach ($file in $files) { Remove-Item -LiteralPath (Join-Path $target $file) -ErrorAction Stop }
Remove-Item -LiteralPath $target -ErrorAction Stop
Write-Output 'Removed only the owned patch folder. Original game files and launchers were unchanged.'
