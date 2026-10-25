#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string[]]$SolutionZip,
    [string]$PacPath = 'pac',
    [switch]$KeepResults
)
$ErrorActionPreference = 'Stop'
$starter = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $starter 'scripts/PowerPlatform.psm1') -Force -DisableNameChecking
$work = Join-Path ([IO.Path]::GetTempPath()) "pp real pac smoke $([guid]::NewGuid().ToString('N'))"
function Fingerprint([string]$Root) {
    $files = @(Get-ChildItem -LiteralPath (Join-Path $Root 'src') -File -Recurse)
    $files += Get-Item -LiteralPath (Join-Path $Root '.powerplatform/source-manifest.json')
    return @($files | Sort-Object FullName | ForEach-Object {
        "$([IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\', '/'))=$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
    }) -join "`n"
}
try {
    foreach ($inputPath in $SolutionZip) {
        $inputFile = Get-Item -LiteralPath $inputPath -ErrorAction Stop
        $root = Join-Path $work ([IO.Path]::GetFileNameWithoutExtension($inputFile.Name))
        foreach ($dir in @('.powerplatform', 'Solutions')) { [IO.Directory]::CreateDirectory((Join-Path $root $dir)) | Out-Null }
        foreach ($name in @('config.json', 'tooling.lock.json')) {
            Copy-Item -LiteralPath (Join-Path $starter ".powerplatform/$name") -Destination (Join-Path $root ".powerplatform/$name")
        }
        Copy-Item -LiteralPath $inputFile.FullName -Destination (Join-Path $root 'Solutions')
        $result = Invoke-RepositoryUnpack -Root $root -PacPath $PacPath -WarningAction SilentlyContinue
        $before = Fingerprint $root
        # The smoke workspace deliberately has no Git history. Only its disposable output is replaced.
        Invoke-RepositoryUnpack -Root $root -PacPath $PacPath -AllowDirty -WarningAction SilentlyContinue | Out-Null
        if ((Fingerprint $root) -ne $before) { throw "Non-deterministic unpacked output: $($inputFile.Name)" }
        if (@(Get-ChildItem -LiteralPath (Join-Path $root 'src') -File -Recurse -Filter '*.msapr').Count -gt 0) { throw 'Intermediate .msapr leaked into source.' }
        foreach ($app in $result.apps) {
            if (-not (Test-Path -LiteralPath (Join-Path $root "$($app.reviewSource)/App.pa.yaml"))) { throw "Missing app YAML: $($app.logicalName)" }
        }
        $yamlCount = @($result.apps | ForEach-Object { $_.yamlFiles } | Measure-Object -Sum).Sum
        Write-Host "PASS real PAC: $($result.solutionUniqueName) $($result.solutionVersion), $($result.apps.Count) app(s), $yamlCount YAML files; repeat output identical."
    }
    Write-Host 'Local unpack validation only. No authentication, Studio changes, imports, publishing, or runtime tests.'
} finally {
    if ($KeepResults) { Write-Host "Results retained at: $work" }
    elseif (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
