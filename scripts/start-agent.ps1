#Requires -Version 7.0
[CmdletBinding()]
param(
    # Claude Code is not launched here: it loads the plugins natively in project scope (SETUP.md 3A).
    [Parameter(Mandatory, Position = 0)][ValidateSet('pi', 'copilot')][string]$Harness,
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [Parameter(ValueFromRemainingArguments)][string[]]$AgentArguments
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'PowerPlatform.psm1') -Force -DisableNameChecking
$Root = Get-ProjectRoot $Root
Assert-ToolingReady $Root $Harness
Get-Command $Harness -ErrorAction Stop | Out-Null
$variables = @{
    POWER_PLATFORM_SKILLS_CONFIG_DIR = (Join-Path $Root '.powerplatform/state/skills')
    FLOWAGENT_TELEMETRY_LOG = (Join-Path $Root '.powerplatform/state/flowagent/telemetry.jsonl')
    POWER_PLATFORM_SKILLS_TELEMETRY_POWER_AUTOMATE_OPTOUT = '1'
}
$previous = @{}
foreach ($key in $variables.Keys) {
    $previous[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
    [Environment]::SetEnvironmentVariable($key, $variables[$key], 'Process')
}
$exitCode = 1
Push-Location $Root
try {
    if ($Harness -eq 'pi') { & pi @AgentArguments }
    else {
        $plugins = @(
            '--plugin-dir', (Join-Path $Root '.powerplatform/runtime/plugins/canvas-apps'),
            '--plugin-dir', (Join-Path $Root '.powerplatform/runtime/plugins/power-automate')
        )
        & $Harness @plugins @AgentArguments
    }
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
    foreach ($key in $variables.Keys) { [Environment]::SetEnvironmentVariable($key, $previous[$key], 'Process') }
}
exit $exitCode
