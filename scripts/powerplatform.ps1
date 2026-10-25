#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Position = 0)][ValidateSet('doctor', 'unpack', 'setup', 'target')][string]$Command = 'doctor',
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [string]$PacPath = 'pac',
    [ValidateSet('pi', 'claude', 'copilot', 'generic')][string]$Harness,
    [switch]$Preview,
    [switch]$AllowDirty,
    [switch]$WithHerdr,
    [string]$AppAlias,
    [string]$StudioUrl
)
$ErrorActionPreference = 'Stop'
if ($WithHerdr -and $Command -ne 'setup') { throw '-WithHerdr applies only to setup -Harness pi.' }
Import-Module (Join-Path $PSScriptRoot 'PowerPlatform.psm1') -Force -DisableNameChecking
switch ($Command) {
    'doctor' { Show-ProjectDoctor -Root $Root -PacPath $PacPath }
    'unpack' { Invoke-RepositoryUnpack -Root $Root -PacPath $PacPath -Preview:$Preview -AllowDirty:$AllowDirty | Out-Null }
    'target' {
        if (-not $AppAlias -or -not $StudioUrl) { throw 'Provide -AppAlias <alias> -StudioUrl <full Studio edit URL>.' }
        Set-StudioTarget -Root $Root -AppAlias $AppAlias -StudioUrl $StudioUrl
    }
    'setup' {
        if (-not $Harness) { throw 'Choose a project-local setup: -Harness pi|claude|copilot|generic' }
        Initialize-ProjectTooling -Root $Root -Harness $Harness -WithHerdr:$WithHerdr
    }
}
