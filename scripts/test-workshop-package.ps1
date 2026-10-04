param(
    [string]$WorkshopFolder = 'C:\Users\ask13\Zomboid\Workshop\ActionTimeReducer',
    [string]$GamePath = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid',
    [string]$Javac = 'C:\Users\ask13\.jdks\ms-21.0.8\bin\javac.exe'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$build = Join-Path $repo '.build'
New-Item -ItemType Directory -Path $build -Force | Out-Null
& $Javac -d $build (Join-Path $repo 'tests/WorkshopValidation.java')
if ($LASTEXITCODE -ne 0) { throw 'Workshop validation harness compilation failed' }
Push-Location $GamePath
try {
    & (Join-Path $GamePath 'jre64/bin/java.exe') "-Djava.library.path=$GamePath\win64;$GamePath" -cp "$build;$GamePath\projectzomboid.jar" WorkshopValidation $WorkshopFolder
    if ($LASTEXITCODE -ne 0) { throw 'Installed game rejected the Workshop package' }
} finally { Pop-Location }
