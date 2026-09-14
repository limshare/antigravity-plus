$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $repo 'patch.ps1') -SkipMain
$runtimeRoot = Install-AntigravityPlusRuntimeFiles -SourceRoot $repo
$patchPath = Join-Path $runtimeRoot 'patch.ps1'
Install-AntigravityPlusLauncherBatch -PatchScriptPath $patchPath | Out-Null
Install-AntigravityPlusLauncherScript -PatchScriptPath $patchPath | Out-Null
Write-Host 'Runtime files synced successfully.'
