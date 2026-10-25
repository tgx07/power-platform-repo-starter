#Requires -Version 7.0
# Offline regression suite. Requires Git and PowerShell 7; no Pester/modules/network.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$starter = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $starter 'scripts/PowerPlatform.psm1') -Force -Global -DisableNameChecking
$fakePac = Join-Path $PSScriptRoot 'fake-pac.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "pp starter tests $([guid]::NewGuid().ToString('N'))"
$script:passed = 0
$script:failed = 0

function Assert($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Expect-Failure([scriptblock]$Action, [string]$Pattern) {
    $caught = $null
    try { & $Action | Out-Null } catch { $caught = $_ }
    Assert ($null -ne $caught) "Expected failure matching $Pattern"
    Assert ("$caught" -match $Pattern) "Expected '$Pattern', got '$caught'"
}
function Invoke-TestGit([string]$Root, [string[]]$Arguments) {
    & git -C $Root @Arguments 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Test Git command failed: $($Arguments -join ' ')" }
}
function New-Project {
    $root = Join-Path $testRoot ([guid]::NewGuid().ToString('N'))
    foreach ($dir in @('.powerplatform', 'Solutions', 'src')) { [IO.Directory]::CreateDirectory((Join-Path $root $dir)) | Out-Null }
    foreach ($name in @('config.json', 'tooling.lock.json')) { Copy-Item -LiteralPath (Join-Path $starter ".powerplatform/$name") -Destination (Join-Path $root ".powerplatform/$name") }
    Copy-Item -LiteralPath (Join-Path $starter '.agents') -Destination (Join-Path $root '.agents') -Recurse
    [IO.File]::WriteAllText((Join-Path $root 'src/.gitkeep'), '')
    Invoke-TestGit $root @('init', '-b', 'main')
    Invoke-TestGit $root @('config', 'user.name', 'Starter Tests')
    Invoke-TestGit $root @('config', 'user.email', 'starter-tests@example.invalid')
    Invoke-TestGit $root @('config', 'commit.gpgsign', 'false')
    Invoke-TestGit $root @('config', 'core.hooksPath', (Join-Path $root '.git/hooks'))
    Commit-Source $root
    return $root
}
function Commit-Source([string]$Root) {
    Invoke-TestGit $Root @('add', 'src', '.powerplatform/config.json', '.powerplatform/tooling.lock.json')
    if (Test-Path -LiteralPath (Join-Path $Root '.powerplatform/source-manifest.json')) { Invoke-TestGit $Root @('add', '.powerplatform/source-manifest.json') }
    Invoke-TestGit $Root @('commit', '--allow-empty', '-m', 'test snapshot')
}
function New-Export([string]$Root, [string]$FileName = 'export.zip', [string]$Version = '1.0.0.0', [string[]]$Apps = @('contoso_booking_abc12'), [string]$Identity = 'Example', [string]$Managed = '0', [hashtable]$Flags = @{}) {
    $path = Join-Path $Root "Solutions/$FileName"
    $zip = [IO.Compression.ZipFile]::Open($path, 'Create')
    try {
        $fixture = @{ apps = $Apps; failSolution = $false; failCanvas = $false; extraFile = $false; missingApp = $false; unmapped = $false }
        foreach ($key in $Flags.Keys) { $fixture[$key] = $Flags[$key] }
        $entries = @{
            'solution.xml' = "<ImportExportXml><SolutionManifest><UniqueName>$Identity</UniqueName><Version>$Version</Version><Managed>$Managed</Managed></SolutionManifest></ImportExportXml>"
            'fixture.json' = ($fixture | ConvertTo-Json)
        }
        foreach ($key in $entries.Keys) {
            $writer = [IO.StreamWriter]::new($zip.CreateEntry($key).Open())
            try { $writer.Write($entries[$key]) } finally { $writer.Dispose() }
        }
    } finally { $zip.Dispose() }
    return $path
}
function Unpack([string]$Root, [switch]$AllowDirty) { Invoke-RepositoryUnpack -Root $Root -PacPath $fakePac -AllowDirty:$AllowDirty -WarningAction SilentlyContinue }
function Fingerprint([string]$Root) {
    return (@(Get-ChildItem -LiteralPath (Join-Path $Root 'src') -Recurse -File | Sort-Object FullName | ForEach-Object {
        "$([IO.Path]::GetRelativePath($Root, $_.FullName))=$((Get-FileHash -LiteralPath $_.FullName).Hash)"
    }) -join "`n") + "`n" + (Get-Content -LiteralPath (Join-Path $Root '.powerplatform/source-manifest.json') -Raw)
}
function Add-TestVendor([string]$Root, [switch]$WithoutDataSource) {
    $vendor = Join-Path $Root '.powerplatform/vendor/power-platform-skills'
    $assets = @('plugins/canvas-apps/references/CreateWorkflow.md', 'plugins/canvas-apps/agents/canvas-screen-builder.md', 'plugins/power-automate/server/mcp.mjs', 'shared/telemetry/.gitkeep', 'LICENSE')
    if (-not $WithoutDataSource) { $assets += 'plugins/canvas-apps/skills/add-data-source/SKILL.md' }
    foreach ($asset in $assets) {
        $path = Join-Path $vendor $asset
        [IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
        [IO.File]::WriteAllText($path, 'synthetic offline upstream fixture')
    }
    Invoke-TestGit $vendor @('init', '-b', 'main')
    Invoke-TestGit $vendor @('config', 'user.name', 'Starter Tests')
    Invoke-TestGit $vendor @('config', 'user.email', 'starter-tests@example.invalid')
    Invoke-TestGit $vendor @('config', 'commit.gpgsign', 'false')
    Invoke-TestGit $vendor @('config', 'core.hooksPath', (Join-Path $vendor '.git/hooks'))
    Invoke-TestGit $vendor @('add', '.')
    Invoke-TestGit $vendor @('commit', '-m', 'synthetic upstream')
    $commit = (& git -C $vendor rev-parse HEAD).Trim()
    $path = Join-Path $Root '.powerplatform/tooling.lock.json'
    $lock = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
    $lock.powerPlatformSkills.commit = $commit
    $lock | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path
    Copy-Item -LiteralPath (Join-Path $starter '.powerplatform/skill-templates') -Destination (Join-Path $Root '.powerplatform/skill-templates') -Recurse
    Copy-Item -LiteralPath (Join-Path $starter '.powerplatform/herdr') -Destination (Join-Path $Root '.powerplatform/herdr') -Recurse
}
function Test([string]$Name, [scriptblock]$Action) {
    try { & $Action; $script:passed++; Write-Host "PASS $Name" -ForegroundColor Green }
    catch { $script:failed++; Write-Host "FAIL $Name`n$_`n$($_.ScriptStackTrace)" -ForegroundColor Red }
}

try {
    Test 'numeric versions beat filename order and timestamps; all apps unpack' {
        $r = New-Project
        New-Export $r 'zzz-newest-name.zip' '1.9.999.9' | Out-Null
        New-Export $r 'aaa-oldest-name.zip' '1.10.0.0' @('contoso_booking_abc12', 'contoso_booking_mobile') | Out-Null
        $result = Unpack $r
        Assert ($result.solutionVersion -eq '1.10.0.0') 'Wrong numeric selection'
        Assert ($result.apps.Count -eq 2) 'Missing app'
        foreach ($alias in @('contoso_booking', 'contoso_booking_mobile')) { Assert (Test-Path -LiteralPath (Join-Path $r "src/CanvasApps/$alias/Src/App.pa.yaml")) "Missing $alias" }
        Assert (@(Get-ChildItem -LiteralPath (Join-Path $r 'src') -Recurse -Filter '*.msapr').Count -eq 0) 'Intermediate leaked'
        Assert (Test-Path -LiteralPath (Join-Path $r 'src/Other/preserved-asset.txt')) 'Exported asset lost'
    }
    Test 'same input produces byte-identical source and provenance' {
        $r = New-Project; New-Export $r | Out-Null; Unpack $r | Out-Null
        $before = Fingerprint $r; Commit-Source $r; Unpack $r | Out-Null
        Assert ((Fingerprint $r) -eq $before) 'Non-deterministic generated output'
    }
    Test 'obsolete apps and source disappear after a newer export' {
        $r = New-Project; New-Export $r | Out-Null; Unpack $r | Out-Null; Commit-Source $r
        New-Export $r 'next.zip' '1.0.0.1' @() | Out-Null; Unpack $r | Out-Null
        Assert (-not (Test-Path -LiteralPath (Join-Path $r 'src/CanvasApps/contoso_booking'))) 'Stale app retained'
    }
    Test 'dirty generated files are protected, explicit override works' {
        $r = New-Project; New-Export $r | Out-Null; Unpack $r | Out-Null
        Expect-Failure { Unpack $r } 'Uncommitted generated-source'
        Unpack $r -AllowDirty | Out-Null
    }
    Test 'dirty provenance is protected' {
        $r = New-Project; New-Export $r | Out-Null; Unpack $r | Out-Null; Commit-Source $r
        Add-Content -LiteralPath (Join-Path $r '.powerplatform/source-manifest.json') -Value ' '
        Expect-Failure { Unpack $r } 'Uncommitted generated-source'
    }
    Test 'preview does not invoke PAC or change source' {
        $r = New-Project; New-Export $r | Out-Null
        Invoke-RepositoryUnpack -Root $r -PacPath 'not-a-real-pac' -Preview | Out-Null
        Assert (-not (Test-Path -LiteralPath (Join-Path $r '.powerplatform/source-manifest.json'))) 'Preview wrote provenance'
        Assert (Test-Path -LiteralPath (Join-Path $r 'src/.gitkeep')) 'Preview changed source'
    }
    Test 'managed exports fail, even when older' {
        $r = New-Project; New-Export $r | Out-Null; New-Export $r 'managed.zip' '0.9.0.0' @() 'Example' '1' | Out-Null
        Expect-Failure { Unpack $r } 'Only unmanaged'
    }
    Test 'multiple solution identities fail' {
        $r = New-Project; New-Export $r | Out-Null; New-Export $r 'other.zip' '2.0.0.0' @() 'Other' | Out-Null
        Expect-Failure { Unpack $r } 'One solution per repo'
    }
    Test 'previous provenance binds solution identity' {
        $r = New-Project; $zip = New-Export $r; Unpack $r | Out-Null; Commit-Source $r
        Remove-Item -LiteralPath $zip; New-Export $r 'other.zip' '2.0.0.0' @() 'Other' | Out-Null
        Expect-Failure { Unpack $r } 'Solution identity changed'
    }
    Test 'same-version differing exports fail; identical copies are allowed' {
        $r = New-Project; $zip = New-Export $r; Copy-Item -LiteralPath $zip -Destination (Join-Path $r 'Solutions/copy.zip')
        Unpack $r | Out-Null
        Remove-Item -LiteralPath (Join-Path $r 'Solutions/copy.zip')
        New-Export $r 'different.zip' '1.0.0.0' @() | Out-Null
        Expect-Failure { Unpack $r } 'Conflicting exports'
    }
    Test 'alias collisions fail instead of merging apps' {
        $r = New-Project; New-Export $r -Apps @('contoso_booking_abc12', 'contoso_booking_def34') | Out-Null
        Expect-Failure { Unpack $r } 'alias collision'
    }
    Test 'explicit alias overrides resolve collisions' {
        $r = New-Project; New-Export $r -Apps @('contoso_booking_abc12', 'contoso_booking_def34') | Out-Null
        $path = Join-Path $r '.powerplatform/config.json'; $config = Get-Content $path -Raw | ConvertFrom-Json -AsHashtable
        $config.appAliases.contoso_booking_def34 = 'contoso_booking_mobile'; $config | ConvertTo-Json -Depth 10 | Set-Content $path
        $result = Unpack $r; Assert ($result.apps.Count -eq 2) 'Override failed'
    }
    Test 'unsafe aliases fail' {
        $r = New-Project; New-Export $r | Out-Null
        $path = Join-Path $r '.powerplatform/config.json'; $config = Get-Content $path -Raw | ConvertFrom-Json -AsHashtable
        $config.appAliases.contoso_booking_abc12 = '../outside'; $config | ConvertTo-Json -Depth 10 | Set-Content $path
        Expect-Failure { Unpack $r } 'Unsafe/nonportable'
    }
    foreach ($case in @(
        @{ Flag = 'failSolution'; Message = 'PAC failed' },
        @{ Flag = 'failCanvas'; Message = 'PAC failed' },
        @{ Flag = 'missingApp'; Message = 'no Src/App.pa.yaml' },
        @{ Flag = 'extraFile'; Message = 'Unexpected non-YAML' },
        @{ Flag = 'unmapped'; Message = 'Unmapped Canvas package' }
    )) {
        Test "failed regeneration preserves source and provenance: $($case.Flag)" {
            $r = New-Project; New-Export $r | Out-Null; Unpack $r | Out-Null; Commit-Source $r
            $before = Fingerprint $r; New-Export $r 'bad-newer.zip' '2.0.0.0' -Flags @{ $case.Flag = $true } | Out-Null
            Expect-Failure { Unpack $r } $case.Message
            Assert ((Fingerprint $r) -eq $before) 'Previous generated source/provenance changed'
            Assert (@(Get-ChildItem -LiteralPath (Join-Path $r '.powerplatform') -Directory -Filter 'staging-*').Count -eq 0) 'Staging leaked'
        }
    }
    Test 'manifest replacement failure rolls back already replaced source' {
        $r = New-Project; New-Export $r | Out-Null; Unpack $r | Out-Null; Commit-Source $r
        $before = Fingerprint $r; New-Export $r 'next.zip' '2.0.0.0' @('contoso_new_abc12') | Out-Null
        $module = Get-Module PowerPlatform
        & $module {
            function script:Copy-Item {
                [CmdletBinding()]param([string]$LiteralPath, [string]$Destination, [switch]$Recurse, [switch]$Force)
                if ($Destination.Replace('\', '/').EndsWith('/.powerplatform/source-manifest.json')) { throw 'injected manifest replacement failure' }
                Microsoft.PowerShell.Management\Copy-Item @PSBoundParameters
            }
        }
        try { Expect-Failure { Unpack $r } 'injected manifest replacement failure' }
        finally { Import-Module (Join-Path $starter 'scripts/PowerPlatform.psm1') -Force -Global -DisableNameChecking }
        Assert ((Fingerprint $r) -eq $before) 'Transaction rollback lost previous source/provenance'
    }
    Test 'rollback failure retains source and provenance recovery files' {
        $r = New-Project; New-Export $r | Out-Null; Unpack $r | Out-Null; Commit-Source $r
        New-Export $r 'next.zip' '2.0.0.0' @('contoso_new_abc12') | Out-Null
        $module = Get-Module PowerPlatform
        & $module {
            function script:Copy-Item {
                [CmdletBinding()]param([string]$LiteralPath, [string]$Destination, [switch]$Recurse, [switch]$Force)
                if ($Destination.Replace('\', '/').EndsWith('/.powerplatform/source-manifest.json')) { throw 'injected manifest failure' }
                Microsoft.PowerShell.Management\Copy-Item @PSBoundParameters
            }
            function script:Move-Item {
                [CmdletBinding()]param([string]$LiteralPath, [string]$Destination)
                if ($LiteralPath.EndsWith('previous-src')) { throw 'injected rollback failure' }
                Microsoft.PowerShell.Management\Move-Item @PSBoundParameters
            }
        }
        try { Expect-Failure { Unpack $r } 'Replacement and rollback failed' }
        finally { Import-Module (Join-Path $starter 'scripts/PowerPlatform.psm1') -Force -Global -DisableNameChecking }
        $recovery = @(Get-ChildItem -LiteralPath (Join-Path $r '.powerplatform') -Directory -Filter 'staging-*')
        Assert ($recovery.Count -eq 1) 'Recovery staging was deleted'
        Assert (Test-Path -LiteralPath (Join-Path $recovery[0].FullName 'previous-src/Other/Solution.xml')) 'Previous source backup missing'
        Assert (Test-Path -LiteralPath (Join-Path $recovery[0].FullName 'previous-source-manifest.json')) 'Previous provenance backup missing'
    }
    Test 'wrong PAC version is rejected' {
        $r = New-Project; New-Export $r | Out-Null; $env:STARTER_TEST_PAC_VERSION = '9.0.0'
        try { Expect-Failure { Unpack $r } 'PAC 2.8.1 is required' } finally { Remove-Item Env:STARTER_TEST_PAC_VERSION }
    }
    Test 'malformed version is rejected' {
        $r = New-Project; New-Export $r -Version '1.0' | Out-Null
        Expect-Failure { Unpack $r } 'Invalid four-part'
    }
    Test 'ZIP traversal is rejected before PAC' {
        $r = New-Project; $path = New-Export $r
        $zip = [IO.Compression.ZipFile]::Open($path, 'Update')
        try { $zip.CreateEntry('../escape.txt') | Out-Null } finally { $zip.Dispose() }
        Expect-Failure { Unpack $r } 'Unsafe ZIP entry'
    }
    Test 'case-colliding ZIP entries are rejected' {
        $r = New-Project; $path = New-Export $r
        $zip = [IO.Compression.ZipFile]::Open($path, 'Update')
        try { $zip.CreateEntry('SOLUTION.XML') | Out-Null } finally { $zip.Dispose() }
        Expect-Failure { Unpack $r } 'Duplicate/case-colliding'
    }
    Test 'exclusive project lock prevents concurrent writers' {
        $r = New-Project; New-Export $r | Out-Null
        $mutex = [IO.File]::Open((Join-Path $r '.powerplatform/unpack.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
        try { Expect-Failure { Unpack $r } 'being used|another process|sharing|access' } finally { $mutex.Dispose() }
    }
    Test 'no ZIPs fail clearly' {
        $r = New-Project; Expect-Failure { Unpack $r } 'No solution ZIPs'
    }
    Test 'Studio target decodes provider app-id and preserves unrelated local settings' {
        $r = New-Project; New-Export $r | Out-Null; Unpack $r | Out-Null
        [IO.File]::WriteAllText((Join-Path $r '.powerplatform/local.json'), '{"schemaVersion":1,"other":"keep"}')
        $url = 'https://make.powerapps.com/e/Default-11111111-1111-1111-1111-111111111111/canvas/?action=edit&app-id=%2Fproviders%2FMicrosoft.PowerApps%2Fapps%2F22222222-2222-2222-2222-222222222222'
        Set-StudioTarget $r 'contoso_booking' $url
        $local = Get-Content -LiteralPath (Join-Path $r '.powerplatform/local.json') -Raw | ConvertFrom-Json -AsHashtable
        Assert ($local.other -eq 'keep') 'Unrelated local setting lost'
        Assert ($local.canvasTargets.contoso_booking_abc12.appId -eq '22222222-2222-2222-2222-222222222222') 'App ID was not decoded'
        Assert ($local.canvasTargets.contoso_booking_abc12.environmentCategory -eq 'prod') 'Wrong category'
    }
    Test 'Studio target rejects unknown aliases/hosts and player URLs' {
        $r = New-Project; New-Export $r | Out-Null; Unpack $r | Out-Null
        Expect-Failure { Set-StudioTarget $r 'missing' 'https://example.com/' } 'Unknown/ambiguous'
        Expect-Failure { Set-StudioTarget $r 'contoso_booking' 'https://example.com/' } 'Unrecognized Studio'
        Expect-Failure { Set-StudioTarget $r 'contoso_booking' 'https://make.powerapps.com/play/app' } 'Expected a Studio URL'
        Expect-Failure { Set-StudioTarget $r 'contoso_booking' 'https://make.powerapps.com/e/11111111-1111-1111-1111-111111111111/canvas/?action=edit' } 'exactly one app-id'
    }
    Test 'Pi setup is local, idempotent, pinned, and preserves unrelated MCP entries' {
        $r = New-Project; Add-TestVendor $r
        [IO.Directory]::CreateDirectory((Join-Path $r '.pi')) | Out-Null
        [IO.File]::WriteAllText((Join-Path $r '.pi/mcp.json'), '{"otherSetting":true,"mcpServers":{"other":{"command":"other-tool"}}}')
        Initialize-ProjectTooling $r 'pi'; Initialize-ProjectTooling $r 'pi'
        $config = Get-Content -LiteralPath (Join-Path $r '.pi/mcp.json') -Raw | ConvertFrom-Json -AsHashtable
        Assert $config.otherSetting 'Unrelated config lost'
        Assert ($config.mcpServers.other.command -eq 'other-tool') 'Unrelated server lost'
        Assert ($config.mcpServers['canvas-authoring'].command -eq 'dotnet') 'Use cross-platform dotnet dnx rather than a shell shim'
        Assert ($config.mcpServers['canvas-authoring'].args[1] -match '@1.1.29$') 'MCP not pinned'
        Assert ($config.mcpServers.flowagent.exposure -eq 'deferred') 'Flow tools should be deferred'
        Assert (Test-Path -LiteralPath (Join-Path $r '.agents/skills/powerplatform-canvas/SKILL.md')) 'Adapter not installed'
        Assert-ToolingReady $r 'pi'
    }
    Test 'setup refuses conflicting user-managed MCP entries without overwriting them' {
        $r = New-Project; Add-TestVendor $r
        [IO.Directory]::CreateDirectory((Join-Path $r '.pi')) | Out-Null
        $path = Join-Path $r '.pi/mcp.json'; $json = '{"mcpServers":{"flowagent":{"command":"my-own-command"}}}'
        [IO.File]::WriteAllText($path, $json)
        Expect-Failure { Initialize-ProjectTooling $r 'pi' } 'differs'
        Assert (([IO.File]::ReadAllText($path)) -eq $json) 'User config was overwritten'
    }
    Test 'setup refuses non-starter skills; native mode does not delete unrelated files' {
        $r = New-Project; Add-TestVendor $r
        $path = Join-Path $r '.agents/skills/powerplatform-canvas'; [IO.Directory]::CreateDirectory($path) | Out-Null
        [IO.File]::WriteAllText((Join-Path $path 'SKILL.md'), 'my own skill')
        Expect-Failure { Initialize-ProjectTooling $r 'claude' } 'non-starter skill'
        Assert (([IO.File]::ReadAllText((Join-Path $path 'SKILL.md'))) -eq 'my own skill') 'User skill deleted'
    }
    Test 'native setup removes only generated adapters and writes no standalone MCP config' {
        $r = New-Project; Add-TestVendor $r
        Initialize-ProjectTooling $r 'generic'
        Initialize-ProjectTooling $r 'copilot'
        Assert (-not (Test-Path -LiteralPath (Join-Path $r '.agents/skills/powerplatform-canvas'))) 'Duplicate live adapter retained'
        Assert (-not (Test-Path -LiteralPath (Join-Path $r '.pi/mcp.json'))) 'Unexpected Pi config'
        Assert (Test-Path -LiteralPath (Join-Path $r '.powerplatform/runtime/plugins/power-automate/.mcp.json')) 'Native runtime missing'
        Assert-ToolingReady $r 'copilot'
    }
    Test 'Claude can launch beside a Pi setup; other harness mismatches still block' {
        $r = New-Project; Add-TestVendor $r; Initialize-ProjectTooling $r 'pi'
        Assert-ToolingReady $r 'claude'
        Expect-Failure { Assert-ToolingReady $r 'copilot' } 'Run setup'
        Initialize-ProjectTooling $r 'generic'
        Expect-Failure { Assert-ToolingReady $r 'claude' } 'Run setup'
    }
    Test 'setup protects additional files in its generated skill folders' {
        $r = New-Project; Add-TestVendor $r; Initialize-ProjectTooling $r 'pi'
        $note = Join-Path $r '.agents/skills/powerplatform-canvas/my-notes.md'
        [IO.File]::WriteAllText($note, 'keep my notes')
        Expect-Failure { Initialize-ProjectTooling $r 'claude' } 'additional files'
        Assert (Test-Path -LiteralPath $note) 'Additional user file was deleted'
    }
    Test 'setup rejects ignored modifications in its vendor checkout' {
        $r = New-Project; Add-TestVendor $r
        $vendor = Join-Path $r '.powerplatform/vendor/power-platform-skills'
        [IO.File]::WriteAllText((Join-Path $vendor '.gitignore'), 'ignored.local')
        Invoke-TestGit $vendor @('add', '.gitignore'); Invoke-TestGit $vendor @('commit', '-m', 'ignore rule fixture')
        $path = Join-Path $r '.powerplatform/tooling.lock.json'
        $lock = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
        $lock.powerPlatformSkills.commit = (& git -C $vendor rev-parse HEAD).Trim()
        $lock | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path
        [IO.File]::WriteAllText((Join-Path $vendor 'ignored.local'), 'untrusted ignored asset')
        Expect-Failure { Initialize-ProjectTooling $r 'pi' } 'including ignored files'
    }
    Test 'configuration review skill is available offline and survives native setup' {
        $r = New-Project
        $skill = Join-Path $r '.agents/skills/powerplatform-configuration/SKILL.md'
        Assert (Test-Path -LiteralPath $skill) 'Baseline configuration skill missing'
        Assert (-not (Test-Path -LiteralPath (Join-Path $r '.powerplatform/setup-state.json'))) 'Offline skill unexpectedly required live setup'
        $before = (Get-FileHash -LiteralPath $skill).Hash
        Add-TestVendor $r; Initialize-ProjectTooling $r 'claude'
        Assert ((Get-FileHash -LiteralPath $skill).Hash -eq $before) 'Native setup modified baseline configuration guidance'
    }
    Test 'setup rejects upstream assets missing Canvas data-source guidance' {
        $r = New-Project; Add-TestVendor $r -WithoutDataSource
        Expect-Failure { Initialize-ProjectTooling $r 'pi' } 'Incomplete upstream plugin.*add-data-source'
    }
    Test 'Herdr orchestration is opt-in and installs only for Pi' {
        $r = New-Project; Add-TestVendor $r; Initialize-ProjectTooling $r 'pi'
        $skill = Join-Path $r '.agents/skills/powerplatform-canvas-herdr/SKILL.md'
        Assert (-not (Test-Path -LiteralPath $skill)) 'Herdr adapter installed without opt-in'
        Initialize-ProjectTooling -Root $r -Harness pi -WithHerdr
        Assert (Test-Path -LiteralPath $skill) 'Optional Herdr adapter missing'
        $state = Get-Content -LiteralPath (Join-Path $r '.powerplatform/setup-state.json') -Raw | ConvertFrom-Json -AsHashtable
        Assert $state.herdrSpecialists 'Herdr mode missing from local setup state'
        Assert (Test-Path -LiteralPath (Join-Path $r '.powerplatform/herdr/worker.md')) 'Worker instructions missing'
        Initialize-ProjectTooling $r 'pi'
        Assert (-not (Test-Path -LiteralPath $skill)) 'Plain setup did not remove the optional generated adapter'
    }
    Test 'Herdr opt-in rejects other harnesses before writing state' {
        $r = New-Project; Add-TestVendor $r
        foreach ($harness in @('generic', 'claude', 'copilot')) {
            Expect-Failure { Initialize-ProjectTooling -Root $r -Harness $harness -WithHerdr } 'only supported with.*pi'
        }
        Assert (-not (Test-Path -LiteralPath (Join-Path $r '.powerplatform/setup-state.json'))) 'Invalid setup wrote state'
    }
    Test 'optional Herdr skill protects unrelated files on disable' {
        $r = New-Project; Add-TestVendor $r; Initialize-ProjectTooling -Root $r -Harness pi -WithHerdr
        $note = Join-Path $r '.agents/skills/powerplatform-canvas-herdr/my-notes.md'
        [IO.File]::WriteAllText($note, 'preserve')
        Expect-Failure { Initialize-ProjectTooling $r 'pi' } 'additional files'
        Assert (Test-Path -LiteralPath $note) 'Optional-skill note was deleted'
    }
    Test 'setup rejects dirty vendor and changed lock blocks launching' {
        $r = New-Project; Add-TestVendor $r; Initialize-ProjectTooling $r 'pi'
        Add-Content -LiteralPath (Join-Path $r '.powerplatform/vendor/power-platform-skills/LICENSE') -Value 'changed'
        Expect-Failure { Initialize-ProjectTooling $r 'pi' } 'local changes'
        Add-Content -LiteralPath (Join-Path $r '.powerplatform/tooling.lock.json') -Value ' '
        Expect-Failure { Assert-ToolingReady $r 'pi' } 'Run setup'
    }
    Test 'flow connector actions without authentication are reported with nested paths' {
        $r = Join-Path $testRoot ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory((Join-Path $r 'Workflows')) | Out-Null
        $auth = @{ authentication = "@parameters('`$authentication')"; host = @{ connectionName = 'shared_office365' } }
        $bare = @{ host = @{ connectionName = 'shared_office365' } }
        $definition = @{ properties = @{ definition = @{ actions = @{
            Kept = @{ type = 'OpenApiConnection'; inputs = $auth }
            Compose = @{ type = 'Compose'; inputs = 'x' }
            Try = @{ type = 'Scope'; actions = @{ Send = @{ type = 'OpenApiConnection'; inputs = $bare } } }
            Check = @{ type = 'If'; actions = @{}; else = @{ actions = @{ Notify = @{ type = 'OpenApiConnection'; inputs = $bare } } } }
            Route = @{ type = 'Switch'; cases = @{ A = @{ actions = @{ Grant = @{ type = 'OpenApiConnection'; inputs = $bare } } } }; default = @{ actions = @{} } }
        } } } }
        [IO.File]::WriteAllText((Join-Path $r 'Workflows/FLOW_X-33333333-3333-3333-3333-333333333333.json'), ($definition | ConvertTo-Json -Depth 20))
        $gaps = @(Get-FlowAuthenticationGaps $r)
        Assert ($gaps.Count -eq 3) "Expected 3 gaps, got: $($gaps -join '; ')"
        foreach ($expected in @('FLOW_X: Check/else/Notify', 'FLOW_X: Route/A/Grant', 'FLOW_X: Try/Send')) { Assert ($gaps -contains $expected) "Missing $expected" }
        Assert (@(Get-FlowAuthenticationGaps (Join-Path $r 'missing')).Count -eq 0) 'No Workflows folder must not fail'
    }
    Test 'Canvas YAML tools pass their offline tests' {
        $python = Get-Command python3 -ErrorAction SilentlyContinue
        if (-not $python) { Write-Warning 'python3 not found; skipping scripts/canvas tests.'; return }
        $output = & $python.Source -I (Join-Path $PSScriptRoot 'test_canvas.py') 2>&1
        Assert ($LASTEXITCODE -eq 0) "Canvas tool tests failed:`n$($output -join "`n")"
    }
} finally {
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
Write-Host "`n$script:passed passed; $script:failed failed. Offline tooling checks only."
if ($script:failed -gt 0) { exit 1 }
