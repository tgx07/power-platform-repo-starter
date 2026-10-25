# Requires PowerShell 7. No Power Platform authentication is used by unpack/setup.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-JsonFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing JSON file: $Path" }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
}

function Write-JsonFile([string]$Path, $Value) {
    [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
    $json = ($Value | ConvertTo-Json -Depth 50) + "`n"
    [IO.File]::WriteAllText($Path, $json, [Text.UTF8Encoding]::new($false))
}

function Get-ProjectRoot([string]$Root) {
    $full = [IO.Path]::GetFullPath($Root)
    if (-not (Test-Path -LiteralPath (Join-Path $full '.powerplatform/config.json'))) {
        throw "Not a starter project: $full (.powerplatform/config.json is missing)."
    }
    return $full
}

function Assert-NoLinks([string]$Path) {
    # Do not follow symlinks/junctions when replacing generated content or executing tools.
    if (Test-Path -LiteralPath $Path) {
        $items = @((Get-Item -LiteralPath $Path -Force))
        if (Test-Path -LiteralPath $Path -PathType Container) {
            $items += @(Get-ChildItem -LiteralPath $Path -Recurse -Force)
        }
        foreach ($item in $items) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Symlinks/junctions are not allowed in managed paths: $($item.FullName)"
            }
        }
    }
}

function Get-ProjectSettings([string]$Root) {
    $config = Read-JsonFile (Join-Path $Root '.powerplatform/config.json')
    $lock = Read-JsonFile (Join-Path $Root '.powerplatform/tooling.lock.json')
    if ($config.schemaVersion -ne 1 -or $lock.schemaVersion -ne 1) { throw 'Unsupported configuration schema.' }
    if ($lock.pacVersion -notmatch '^\d+\.\d+\.\d+$') { throw 'PAC must have an exact version.' }
    if ($lock.canvasMcp.package -ne 'Microsoft.PowerApps.CanvasAuthoring.McpServer' -or
        $lock.canvasMcp.version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') { throw 'Canvas MCP must use the expected package and an exact version.' }
    if ($lock.powerPlatformSkills.commit -notmatch '^[0-9a-f]{40}$') { throw 'Skills must be pinned to a full Git commit.' }
    if ($lock.powerPlatformSkills.repository -ne 'https://github.com/microsoft/power-platform-skills.git') {
        throw 'Unexpected upstream skills repository. Review the setup implementation before changing its trust source.'
    }
    return @{ Config = $config; Lock = $lock }
}

function Read-SafeXml([IO.Stream]$Stream) {
    $settings = [Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $settings.MaxCharactersInDocument = 16777216
    $reader = [Xml.XmlReader]::Create($Stream, $settings)
    try {
        $doc = [Xml.XmlDocument]::new()
        $doc.XmlResolver = $null
        $doc.Load($reader)
        return ,$doc
    } finally { $reader.Dispose() }
}

function Get-SolutionCandidates([string]$Root) {
    $directory = Join-Path $Root 'Solutions'
    Assert-NoLinks $directory
    $files = @(Get-ChildItem -LiteralPath $directory -File | Where-Object { $_.Extension -ieq '.zip' } | Sort-Object Name)
    if ($files.Count -eq 0) { throw "No solution ZIPs found directly in $directory" }
    foreach ($file in $files) {
        $zip = [IO.Compression.ZipFile]::OpenRead($file.FullName)
        try {
            # Reject path traversal/case collisions before handing an archive to PAC.
            $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            foreach ($entry in $zip.Entries) {
                $name = $entry.FullName.Replace('\', '/')
                if ($name.StartsWith('/') -or $name.Contains(':') -or $name.Split('/') -contains '..') {
                    throw "Unsafe ZIP entry in $($file.Name): $name"
                }
                if (-not $seen.Add($name)) { throw "Duplicate/case-colliding ZIP entry in $($file.Name): $name" }
            }
            $entries = @($zip.Entries | Where-Object { $_.FullName -ieq 'solution.xml' })
            if ($entries.Count -ne 1) { throw "Expected one root solution.xml in $($file.Name)" }
            $stream = $entries[0].Open()
            try { $xml = Read-SafeXml $stream } finally { $stream.Dispose() }
            $manifest = $xml.SelectSingleNode('/ImportExportXml/SolutionManifest')
            if ($null -eq $manifest) { throw "Missing SolutionManifest in $($file.Name)" }
            $name = $manifest.SelectSingleNode('UniqueName').InnerText
            $versionText = $manifest.SelectSingleNode('Version').InnerText
            $managed = $manifest.SelectSingleNode('Managed').InnerText
            if ([string]::IsNullOrWhiteSpace($name)) { throw "Missing solution identity in $($file.Name)" }
            if ($versionText -notmatch '^\d+\.\d+\.\d+\.\d+$') { throw "Invalid four-part version in $($file.Name): $versionText" }
            if ($managed -ne '0') { throw "Only unmanaged exports are allowed: $($file.Name)" }
            [pscustomobject]@{
                Path = $file.FullName
                FileName = $file.Name
                UniqueName = $name
                Version = [version]$versionText
                Sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        } finally { $zip.Dispose() }
    }
}

function Select-SolutionExport([object[]]$Candidates, $Config, $Previous) {
    $identities = @($Candidates.UniqueName | Sort-Object -Unique)
    if ($identities.Count -ne 1) { throw "One solution per repo is required. Found: $($identities -join ', ')" }
    $expected = $Config.solutionUniqueName
    if ($Previous) {
        if ($expected -and $expected -ne $Previous.solutionUniqueName) { throw 'Configured identity conflicts with source-manifest.json.' }
        $expected = $Previous.solutionUniqueName
    }
    if ($expected -and $identities[0] -ne $expected) { throw "Solution identity changed: expected $expected, found $($identities[0])" }
    foreach ($group in ($Candidates | Group-Object { $_.Version.ToString() })) {
        if (@($group.Group.Sha256 | Sort-Object -Unique).Count -gt 1) {
            throw "Conflicting exports for solution version $($group.Name). Keep exactly the intended export."
        }
    }
    return $Candidates | Sort-Object @{ Expression = 'Version'; Descending = $true }, FileName | Select-Object -First 1
}

function Invoke-Pac([string]$PacPath, [string[]]$Arguments) {
    $command = Get-Command $PacPath -ErrorAction Stop
    $output = @(& $command.Source @Arguments 2>&1 | ForEach-Object { "$_" })
    if ($LASTEXITCODE -ne 0) {
        throw "PAC failed ($LASTEXITCODE): pac $($Arguments -join ' ')`n$($output -join "`n")"
    }
    return $output -join "`n"
}

function Assert-PacVersion([string]$PacPath, [string]$Expected) {
    $output = Invoke-Pac $PacPath @('help')
    if ($output -notmatch '(?m)Version:\s*(\d+\.\d+\.\d+)') { throw 'Cannot identify PAC version from pac help.' }
    if ($Matches[1] -ne $Expected) { throw "PAC $Expected is required by tooling.lock.json; found $($Matches[1]). See SETUP.md." }
    return $Matches[1]
}

function Assert-GitSafety([string]$Root, $Config, [bool]$AllowDirty) {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git is required to check for uncommitted generated-source changes.'
    }
    $inside = & git -C $Root rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0 -or $inside -ne 'true') {
        if ((Test-Path -LiteralPath (Join-Path $Root 'src')) -and
            @(Get-ChildItem -LiteralPath (Join-Path $Root 'src') -Force | Where-Object Name -ne '.gitkeep').Count -gt 0 -and -not $AllowDirty) {
            throw 'Existing src/ has no Git protection. Initialize/commit it first or explicitly use -AllowDirty after backing it up.'
        }
        Write-Warning 'Not in a Git working tree. Initialize Git and use a working branch for review.'
        return
    }
    $branch = & git -C $Root symbolic-ref --short -q HEAD 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Warning 'Detached HEAD: create a working branch before committing the export.' }
    elseif ($branch -in $Config.protectedBranches) { Write-Warning "Unpacking on '$branch'. A separate export/review branch is recommended." }
    $dirty = @(& git -C $Root status --porcelain=v1 --untracked-files=all -- src .powerplatform/source-manifest.json)
    if ($LASTEXITCODE -ne 0) { throw 'Git status failed; refusing to replace generated source.' }
    if ($dirty.Count -gt 0 -and -not $AllowDirty) {
        throw "Uncommitted generated-source changes. Commit/stash them first, or explicitly use -AllowDirty after review.`n$($dirty -join "`n")"
    }
}

function Get-AppAlias([string]$LogicalName, $Config) {
    $alias = if ($Config.appAliases.ContainsKey($LogicalName)) { $Config.appAliases[$LogicalName] }
             else { $LogicalName -replace '_[0-9a-fA-F]{5}$', '' }
    if ($alias -isnot [string] -or $alias -notmatch '^[a-zA-Z0-9][a-zA-Z0-9_-]*$' -or
        $alias -match '^(?i:con|prn|aux|nul|com[0-9]|lpt[0-9])$') {
        throw "Unsafe/nonportable app alias for ${LogicalName}: $alias"
    }
    return $alias
}

function Get-CanvasApps([string]$SourceRoot, $Config) {
    $canvas = Join-Path $SourceRoot 'CanvasApps'
    if (-not (Test-Path -LiteralPath $canvas)) { return }
    $aliases = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $mapped = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($metadata in (Get-ChildItem -LiteralPath $canvas -Filter '*.meta.xml' -File | Sort-Object Name)) {
        $stream = [IO.File]::OpenRead($metadata.FullName)
        try { $xml = Read-SafeXml $stream } finally { $stream.Dispose() }
        $logical = $xml.SelectSingleNode('/CanvasApp/Name').InnerText
        $documentUri = $xml.SelectSingleNode('/CanvasApp/DocumentUri').InnerText.Replace('\', '/')
        if ($documentUri -notmatch '^/?CanvasApps/([^/]+\.msapp)$') { throw "Unsupported DocumentUri in $($metadata.Name): $documentUri" }
        $packageName = $Matches[1]
        $package = Join-Path $canvas $packageName
        if (-not (Test-Path -LiteralPath $package -PathType Leaf)) { throw "Missing Canvas package: $packageName" }
        if (-not $mapped.Add($packageName)) { throw "Canvas package mapped more than once: $packageName" }
        $alias = Get-AppAlias $logical $Config
        if (-not $aliases.Add($alias)) { throw "Canvas alias collision: $alias. Set explicit appAliases in config.json." }
        if (Test-Path -LiteralPath (Join-Path $canvas $alias)) { throw "Canvas alias collides with exported content: $alias" }
        [pscustomobject]@{ LogicalName = $logical; Alias = $alias; Package = $package; PackageName = $packageName }
    }
    foreach ($package in (Get-ChildItem -LiteralPath $canvas -Filter '*.msapp' -File -Recurse)) {
        if (-not $mapped.Contains($package.Name) -or $package.DirectoryName -ne $canvas) {
            throw "Unmapped Canvas package: $($package.FullName). Refusing to omit an app."
        }
    }
}

function Invoke-RepositoryUnpack {
    [CmdletBinding()]
    param([string]$Root, [string]$PacPath = 'pac', [switch]$Preview, [switch]$AllowDirty)
    $Root = Get-ProjectRoot $Root
    Assert-NoLinks (Join-Path $Root '.powerplatform')
    Assert-NoLinks (Join-Path $Root 'src')
    $settings = Get-ProjectSettings $Root
    $manifestPath = Join-Path $Root '.powerplatform/source-manifest.json'
    $previous = if (Test-Path -LiteralPath $manifestPath) { Read-JsonFile $manifestPath } else { $null }
    $selected = Select-SolutionExport @(Get-SolutionCandidates $Root) $settings.Config $previous
    Write-Host "Selected $($selected.FileName): $($selected.UniqueName) $($selected.Version) (unmanaged)"
    Write-Host "Destination: $(Join-Path $Root 'src')"
    if ($Preview) { return $selected }
    Assert-GitSafety $Root $settings.Config $AllowDirty.IsPresent
    $pacVersion = Assert-PacVersion $PacPath $settings.Lock.pacVersion
    # One exclusive writer per project; the empty lock file is ignored and can remain.
    $mutex = [IO.File]::Open((Join-Path $Root '.powerplatform/unpack.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    $work = Join-Path $Root ".powerplatform/staging-$([guid]::NewGuid().ToString('N'))"
    $source = Join-Path $work 'src'
    $destination = Join-Path $Root 'src'
    $backup = Join-Path $work 'previous-src'
    $manifestBackup = if (Test-Path -LiteralPath $manifestPath) { [IO.File]::ReadAllBytes($manifestPath) } else { $null }
    $movedOld = $false
    $movedNew = $false
    $preserveRecovery = $false
    try {
        [IO.Directory]::CreateDirectory($source) | Out-Null
        $inputZip = Join-Path $work 'input.zip'
        Copy-Item -LiteralPath $selected.Path -Destination $inputZip
        if ((Get-FileHash -LiteralPath $inputZip -Algorithm SHA256).Hash.ToLowerInvariant() -ne $selected.Sha256) {
            throw 'Selected ZIP changed while being read. Retry with a stable export.'
        }
        Invoke-Pac $PacPath @('solution', 'unpack', '--zipfile', $inputZip, '--folder', $source, '--packagetype', 'Unmanaged') | Write-Verbose
        $solutionXmlPath = Join-Path $source 'Other/Solution.xml'
        if (-not (Test-Path -LiteralPath $solutionXmlPath)) { throw 'PAC did not produce Other/Solution.xml.' }
        $stream = [IO.File]::OpenRead($solutionXmlPath)
        try { $unpacked = Read-SafeXml $stream } finally { $stream.Dispose() }
        if ($unpacked.ImportExportXml.SolutionManifest.UniqueName -ne $selected.UniqueName -or
            [version]$unpacked.ImportExportXml.SolutionManifest.Version -ne $selected.Version -or
            $unpacked.ImportExportXml.SolutionManifest.Managed -ne '0') { throw 'Unpacked solution identity/version/type does not match the selected ZIP.' }
        $apps = @(Get-CanvasApps $source $settings.Config)
        $appManifest = @()
        foreach ($app in $apps) {
            $canvasWork = Join-Path $work "canvas-$($app.Alias)"
            Invoke-Pac $PacPath @('canvas', 'unpack', '--msapp', $app.Package, '--sources', $canvasWork, '--layout', 'SourceCode', '--overwrite') | Write-Verbose
            $yamlRoot = Join-Path $canvasWork 'Src'
            if (-not (Test-Path -LiteralPath (Join-Path $yamlRoot 'App.pa.yaml'))) { throw "Canvas unpack produced no Src/App.pa.yaml for $($app.LogicalName)" }
            Assert-NoLinks $yamlRoot
            $files = @(Get-ChildItem -LiteralPath $yamlRoot -File -Recurse)
            if (@($files | Where-Object { -not $_.Name.EndsWith('.pa.yaml', [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0) {
                throw "Unexpected non-YAML Canvas review output for $($app.LogicalName)"
            }
            $reviewRoot = Join-Path $source "CanvasApps/$($app.Alias)"
            [IO.Directory]::CreateDirectory($reviewRoot) | Out-Null
            Copy-Item -LiteralPath $yamlRoot -Destination (Join-Path $reviewRoot 'Src') -Recurse
            $appManifest += [ordered]@{
                logicalName = $app.LogicalName; alias = $app.Alias
                package = "src/CanvasApps/$($app.PackageName)"
                reviewSource = "src/CanvasApps/$($app.Alias)/Src"; yamlFiles = $files.Count
            }
        }
        Assert-NoLinks $source
        $manifest = [ordered]@{
            schemaVersion = 1; starterVersion = $settings.Lock.starterVersion
            solutionUniqueName = $selected.UniqueName; solutionVersion = $selected.Version.ToString()
            packageType = 'Unmanaged'; input = "Solutions/$($selected.FileName)"; sha256 = $selected.Sha256
            pacVersion = $pacVersion; canvasLayout = 'SourceCode'; apps = @($appManifest)
        }
        # Stage first. Roll back both source and provenance if replacement fails.
        Write-JsonFile (Join-Path $work 'source-manifest.json') $manifest
        if ($null -ne $manifestBackup) { [IO.File]::WriteAllBytes((Join-Path $work 'previous-source-manifest.json'), $manifestBackup) }
        Assert-GitSafety $Root $settings.Config $AllowDirty.IsPresent
        if (Test-Path -LiteralPath $destination) { Move-Item -LiteralPath $destination -Destination $backup; $movedOld = $true }
        Move-Item -LiteralPath $source -Destination $destination
        $movedNew = $true
        Copy-Item -LiteralPath (Join-Path $work 'source-manifest.json') -Destination $manifestPath -Force
        Write-Host "Unpacked $($selected.Version); generated review source for $($apps.Count) Canvas app(s)."
        return $manifest
    } catch {
        $originalError = $_
        try {
            if ($movedNew -and (Test-Path -LiteralPath $destination)) { Remove-Item -LiteralPath $destination -Recurse -Force }
            if ($movedOld) { Move-Item -LiteralPath $backup -Destination $destination }
            if ($movedNew -or $movedOld) {
                if ($null -ne $manifestBackup) { [IO.File]::WriteAllBytes($manifestPath, $manifestBackup) }
                elseif (Test-Path -LiteralPath $manifestPath) { Remove-Item -LiteralPath $manifestPath }
            }
        } catch {
            $preserveRecovery = $true
            throw "Replacement and rollback failed. Preserve/recover files from '$work' before retrying. Original error: $originalError. Rollback error: $_"
        }
        throw $originalError
    } finally {
        try {
            if (-not $preserveRecovery -and (Test-Path -LiteralPath $work)) { Remove-Item -LiteralPath $work -Recurse -Force }
        } finally { $mutex.Dispose() }
    }
}

function Set-StudioTarget {
    [CmdletBinding()]
    param([string]$Root, [string]$AppAlias, [string]$StudioUrl)
    $Root = Get-ProjectRoot $Root
    Assert-NoLinks (Join-Path $Root '.powerplatform')
    $manifest = Read-JsonFile (Join-Path $Root '.powerplatform/source-manifest.json')
    $apps = @($manifest.apps | Where-Object alias -eq $AppAlias)
    if ($apps.Count -ne 1) { throw "Unknown/ambiguous app alias '$AppAlias'. Unpack first and choose an alias from source-manifest.json." }
    $uri = [uri]$StudioUrl
    if ($uri.Scheme -ne 'https' -or $uri.UserInfo -or -not $uri.IsDefaultPort -or $uri.Fragment) { throw 'Use a complete HTTPS Power Apps Studio edit URL without credentials, custom ports, or fragments.' }
    $hosts = @{
        'make.powerapps.com' = 'prod'; 'make.preview.powerapps.com' = 'prod'
        'make.preprod.powerapps.com' = 'preprod'; 'make.gov.powerapps.us' = 'gov'
        'make.high.powerapps.us' = 'high'; 'make.apps.appsplatform.us' = 'dod'; 'make.powerapps.cn' = 'china'
    }
    if (-not $hosts.ContainsKey($uri.DnsSafeHost)) { throw 'Unrecognized Studio hostname. Review the host explicitly rather than guessing a cloud category.' }
    if ($uri.AbsolutePath -notmatch '^/e/([^/]+)/canvas/?$') { throw 'Expected a Studio URL with /e/<environment-id>/canvas/.' }
    $environmentId = [uri]::UnescapeDataString($Matches[1])
    $parsedEnvironment = [guid]::Empty
    if (-not [guid]::TryParse(($environmentId -replace '^Default-', ''), [ref]$parsedEnvironment)) { throw 'Invalid Studio environment ID.' }
    $query = [Web.HttpUtility]::ParseQueryString($uri.Query)
    $appIds = $query.GetValues('app-id')
    if ($null -eq $appIds -or $appIds.Count -ne 1 -or $query['action'] -ne 'edit') { throw 'Expected action=edit and exactly one app-id in the Studio URL.' }
    $appId = ($query['app-id'].TrimEnd('/') -split '/')[-1]
    $parsedApp = [guid]::Empty
    if (-not [guid]::TryParse($appId, [ref]$parsedApp)) { throw 'Invalid Studio app-id.' }
    $localPath = Join-Path $Root '.powerplatform/local.json'
    $local = if (Test-Path -LiteralPath $localPath) { Read-JsonFile $localPath } else { @{ schemaVersion = 1; canvasTargets = @{} } }
    if (-not $local.ContainsKey('canvasTargets')) { $local.canvasTargets = @{} }
    $logical = $apps[0].logicalName
    $local.canvasTargets[$logical] = [ordered]@{
        logicalName = $logical; alias = $AppAlias; environmentId = $environmentId
        appId = $parsedApp.ToString(); makerHostname = $uri.DnsSafeHost; environmentCategory = $hosts[$uri.DnsSafeHost]
    }
    $local.selectedCanvasApp = $logical
    Write-JsonFile $localPath $local
    Write-Host "Recorded local target for $AppAlias ($logical): environment $environmentId, app $parsedApp"
    Write-Host 'No connection was made. Confirm that this is the intended app and keep its coauthoring Studio tab open.'
}

function Invoke-Git([string[]]$Arguments) {
    $output = @(& git @Arguments 2>&1 | ForEach-Object { "$_" })
    if ($LASTEXITCODE -ne 0) { throw "Git failed: $($output -join "`n")" }
    return $output -join "`n"
}

function Get-McpEntries([string]$Root, $Lock) {
    $runtime = Join-Path $Root '.powerplatform/runtime'
    $envVars = [ordered]@{
        POWER_PLATFORM_SKILLS_CONFIG_DIR = (Join-Path $Root '.powerplatform/state/skills')
        FLOWAGENT_TELEMETRY_LOG = (Join-Path $Root '.powerplatform/state/flowagent/telemetry.jsonl')
        POWER_PLATFORM_SKILLS_TELEMETRY_POWER_AUTOMATE_OPTOUT = '1'
    }
    return [ordered]@{
        'canvas-authoring' = [ordered]@{
            command = 'dotnet'
            args = @('dnx', "$($Lock.canvasMcp.package)@$($Lock.canvasMcp.version)", '--yes')
        }
        flowagent = [ordered]@{
            command = 'node'
            args = @((Join-Path $runtime 'plugins/power-automate/server/mcp.mjs'))
            env = $envVars
        }
    }
}

function Initialize-ProjectTooling {
    [CmdletBinding()]
    param([string]$Root, [ValidateSet('pi', 'claude', 'copilot', 'generic')][string]$Harness, [switch]$WithHerdr)
    if ($WithHerdr -and $Harness -ne 'pi') { throw '-WithHerdr is only supported with -Harness pi.' }
    $Root = Get-ProjectRoot $Root
    Assert-NoLinks (Join-Path $Root '.powerplatform')
    Assert-NoLinks (Join-Path $Root '.agents')
    Assert-NoLinks (Join-Path $Root '.pi')
    $mutex = [IO.File]::Open((Join-Path $Root '.powerplatform/setup.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    try { Initialize-ProjectToolingCore $Root $Harness $WithHerdr.IsPresent } finally { $mutex.Dispose() }
}

function Initialize-ProjectToolingCore([string]$Root, [string]$Harness, [bool]$WithHerdr) {
    $lock = (Get-ProjectSettings $Root).Lock
    $managedSkills = @('powerplatform-canvas', 'powerplatform-flows', 'powerplatform-canvas-herdr')
    $selectedSkills = if ($Harness -in @('pi', 'generic')) { @('powerplatform-canvas', 'powerplatform-flows') } else { @() }
    if ($WithHerdr) { $selectedSkills += 'powerplatform-canvas-herdr' }
    foreach ($name in $selectedSkills) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root ".powerplatform/skill-templates/$name.md") -PathType Leaf)) { throw "Missing local skill template: $name" }
    }
    if ($WithHerdr -and -not (Test-Path -LiteralPath (Join-Path $Root '.powerplatform/herdr/worker.md') -PathType Leaf)) { throw 'Missing Herdr worker instructions.' }
    $vendor = Join-Path $Root '.powerplatform/vendor/power-platform-skills'
    if (-not (Test-Path -LiteralPath $vendor)) {
        [IO.Directory]::CreateDirectory((Split-Path -Parent $vendor)) | Out-Null
        $download = "$vendor.new-$([guid]::NewGuid().ToString('N'))"
        try {
            Invoke-Git @('init', $download) | Write-Verbose
            Invoke-Git @('-C', $download, 'remote', 'add', 'origin', $lock.powerPlatformSkills.repository) | Write-Verbose
            Invoke-Git @('-C', $download, 'fetch', '--depth', '1', 'origin', $lock.powerPlatformSkills.commit) | Write-Verbose
            Invoke-Git @('-C', $download, 'checkout', '--detach', 'FETCH_HEAD') | Write-Verbose
            Move-Item -LiteralPath $download -Destination $vendor
        } finally { if (Test-Path -LiteralPath $download) { Remove-Item -LiteralPath $download -Recurse -Force } }
    }
    $head = Invoke-Git @('-C', $vendor, 'rev-parse', 'HEAD')
    if ($head.Trim() -ne $lock.powerPlatformSkills.commit) {
        throw 'Vendor revision differs from tooling.lock.json. Move/remove .powerplatform/vendor and rerun setup after reviewing the update.'
    }
    if ((Invoke-Git @('-C', $vendor, 'status', '--porcelain', '--untracked-files=all', '--ignored=matching')).Length -gt 0) { throw 'Vendor checkout has local changes (including ignored files); refusing to use modified upstream tooling.' }
    foreach ($path in @('plugins/canvas-apps/references/CreateWorkflow.md', 'plugins/canvas-apps/agents/canvas-screen-builder.md', 'plugins/canvas-apps/skills/add-data-source/SKILL.md', 'plugins/power-automate/server/mcp.mjs', 'shared/telemetry')) {
        if (-not (Test-Path -LiteralPath (Join-Path $vendor $path))) { throw "Incomplete upstream plugin: $path" }
    }
    $entries = Get-McpEntries $Root $lock
    $configPath = if ($Harness -eq 'pi') { Join-Path $Root '.pi/mcp.json' }
                  elseif ($Harness -eq 'generic') { Join-Path $Root '.powerplatform/mcp.json' } else { $null }
    $config = if ($configPath -and (Test-Path -LiteralPath $configPath)) { Read-JsonFile $configPath } else { @{ mcpServers = @{} } }
    if (-not $config.ContainsKey('mcpServers')) { $config.mcpServers = @{} }
    $statePath = Join-Path $Root '.powerplatform/setup-state.json'
    $previousState = if (Test-Path -LiteralPath $statePath) { Read-JsonFile $statePath } else { @{} }
    foreach ($key in $entries.Keys) {
        if ($Harness -eq 'pi') {
            $entries[$key].exposure = 'deferred'
            $entries[$key].description = if ($key -eq 'flowagent') { 'Inspect and author Power Automate flows in the explicitly selected environment.' }
                                          else { 'Connect to a Canvas Studio coauthoring session and inspect or author its YAML.' }
        }
        if ($configPath -and $config.mcpServers.ContainsKey($key)) {
            $existing = $config.mcpServers[$key] | ConvertTo-Json -Depth 50 -Compress
            $desired = $entries[$key] | ConvertTo-Json -Depth 50 -Compress
            $owned = $previousState.ContainsKey('configPath') -and $previousState.configPath -eq $configPath -and
                $previousState.ContainsKey('entries') -and $previousState.entries.ContainsKey($key) -and
                $existing -eq ($previousState.entries[$key] | ConvertTo-Json -Depth 50 -Compress)
            if ($existing -ne $desired -and -not $owned) { throw "Existing MCP '$key' differs in $configPath. Review and reconcile it manually; no unrelated configuration was overwritten." }
        }
    }
    $marker = '<!-- power-platform-repo-starter managed -->'
    foreach ($name in $managedSkills) {
        $skill = Join-Path $Root ".agents/skills/$name"
        if (Test-Path -LiteralPath $skill) {
            $file = Join-Path $skill 'SKILL.md'
            if (-not (Test-Path -LiteralPath $file) -or -not ([IO.File]::ReadAllText($file).Contains($marker))) {
                throw "Refusing to replace an existing non-starter skill: $skill"
            }
            if (@(Get-ChildItem -LiteralPath $skill -Force | Where-Object Name -ne 'SKILL.md').Count -gt 0) {
                throw "Generated skill folder contains additional files; preserve/reconcile them before setup: $skill"
            }
        }
    }
    $runtime = Join-Path $Root '.powerplatform/runtime'
    # Runtime is a disposable overlay; preserve the pinned upstream checkout unchanged.
    # A failed rebuild must not leave a previous readiness marker authorizing a partial runtime.
    if (Test-Path -LiteralPath $statePath) { Remove-Item -LiteralPath $statePath }
    if (Test-Path -LiteralPath $runtime) { Remove-Item -LiteralPath $runtime -Recurse -Force }
    [IO.Directory]::CreateDirectory((Join-Path $runtime 'plugins')) | Out-Null
    foreach ($name in @('canvas-apps', 'power-automate')) {
        Copy-Item -LiteralPath (Join-Path $vendor "plugins/$name") -Destination (Join-Path $runtime "plugins/$name") -Recurse
    }
    Copy-Item -LiteralPath (Join-Path $vendor 'shared') -Destination (Join-Path $runtime 'shared') -Recurse
    Copy-Item -LiteralPath (Join-Path $vendor 'LICENSE') -Destination (Join-Path $runtime 'LICENSE')
    $nativeEntries = Get-McpEntries $Root $lock
    Write-JsonFile (Join-Path $runtime 'plugins/canvas-apps/.mcp.json') @{ mcpServers = @{ 'canvas-authoring' = $nativeEntries['canvas-authoring'] } }
    Write-JsonFile (Join-Path $runtime 'plugins/power-automate/.mcp.json') @{ mcpServers = @{ flowagent = $nativeEntries.flowagent } }
    foreach ($name in $managedSkills) {
        $skill = Join-Path $Root ".agents/skills/$name"
        if ($name -in $selectedSkills) {
            [IO.Directory]::CreateDirectory($skill) | Out-Null
            Copy-Item -LiteralPath (Join-Path $Root ".powerplatform/skill-templates/$name.md") -Destination (Join-Path $skill 'SKILL.md') -Force
        } elseif (Test-Path -LiteralPath $skill) { Remove-Item -LiteralPath $skill -Recurse -Force }
    }
    if ($configPath) {
        foreach ($key in $entries.Keys) { $config.mcpServers[$key] = $entries[$key] }
        Write-JsonFile $configPath $config
    }
    Write-JsonFile $statePath ([ordered]@{
        schemaVersion = 1; harness = $Harness; herdrSpecialists = $WithHerdr; root = $Root; configPath = $configPath
        lockSha256 = (Get-FileHash -LiteralPath (Join-Path $Root '.powerplatform/tooling.lock.json') -Algorithm SHA256).Hash
        entries = $entries
    })
    Write-Host "Prepared $Harness tooling locally. No global skills, plugin registration, MCP configuration, or authentication was changed."
    Write-Host 'See SETUP.md for trust, read-only verification, and host compatibility limits.'
}

function Assert-ToolingReady([string]$Root, [string]$Harness) {
    $state = Read-JsonFile (Join-Path $Root '.powerplatform/setup-state.json')
    $hash = (Get-FileHash -LiteralPath (Join-Path $Root '.powerplatform/tooling.lock.json') -Algorithm SHA256).Hash
    # Claude loads the shared runtime via --plugin-dir and reads neither .pi/mcp.json nor .agents/skills,
    # so it can run beside a Pi setup without registering the live servers twice.
    $harnessReady = $state.harness -eq $Harness -or ($Harness -eq 'claude' -and $state.harness -eq 'pi')
    if ($state.root -ne $Root -or -not $harnessReady -or $state.lockSha256 -ne $hash) {
        throw "Run setup -Harness $Harness again: the harness, project path, or toolchain lock changed."
    }
    foreach ($path in @('plugins/canvas-apps/.mcp.json', 'plugins/power-automate/server/mcp.mjs')) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root ".powerplatform/runtime/$path"))) { throw 'Runtime is incomplete. Rerun setup.' }
    }
}

function Show-ProjectDoctor([string]$Root, [string]$PacPath = 'pac') {
    $Root = Get-ProjectRoot $Root
    $lock = (Get-ProjectSettings $Root).Lock
    Write-Host "Project: $Root"
    $failed = $false
    foreach ($name in @('git', 'dotnet', 'dnx', 'node', 'az')) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) { Write-Host "${name}: $($command.Source)" }
        else { Write-Warning "${name}: not found (see the offline/live prerequisite table in SETUP.md)." }
    }
    try { Write-Host "PAC: $(Assert-PacVersion $PacPath $lock.pacVersion) (matches lock)" }
    catch { $failed = $true; Write-Warning $_ }
    if (Get-Command dotnet -ErrorAction SilentlyContinue) { & dotnet --list-sdks }
    if (Get-Command node -ErrorAction SilentlyContinue) { & node --version }
    Write-Host 'Doctor checks local prerequisites only; it does not authenticate or prove MCP connectivity.'
    if ($failed) { throw 'Offline prerequisites are not ready. See SETUP.md.' }
}

Export-ModuleMember -Function Invoke-RepositoryUnpack, Initialize-ProjectTooling, Set-StudioTarget, Show-ProjectDoctor, Assert-ToolingReady, Get-ProjectRoot
