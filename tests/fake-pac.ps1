# Offline PAC test double. Never contacts Power Platform.
$ErrorActionPreference = 'Stop'
function Argument([string]$Name) {
    $index = [array]::IndexOf($script:arguments, $Name)
    if ($index -lt 0) { throw "Missing fake PAC argument: $Name" }
    return $script:arguments[$index + 1]
}
$script:arguments = $args
if ($args[0] -eq 'help') {
    $version = if ($env:STARTER_TEST_PAC_VERSION) { $env:STARTER_TEST_PAC_VERSION } else { '2.8.1' }
    Write-Output "Microsoft PowerPlatform CLI`nVersion: $version+test"
    exit 0
}
if ($args[0] -eq 'solution') {
    $zip = [IO.Compression.ZipFile]::OpenRead((Argument '--zipfile'))
    try {
        $reader = [IO.StreamReader]::new($zip.GetEntry('fixture.json').Open())
        try { $fixture = $reader.ReadToEnd() | ConvertFrom-Json -AsHashtable } finally { $reader.Dispose() }
        if ($fixture.failSolution) { Write-Output 'injected solution failure'; exit 7 }
        $destination = Argument '--folder'
        [IO.Directory]::CreateDirectory((Join-Path $destination 'Other')) | Out-Null
        $reader = [IO.StreamReader]::new($zip.GetEntry('solution.xml').Open())
        try { [IO.File]::WriteAllText((Join-Path $destination 'Other/Solution.xml'), $reader.ReadToEnd()) } finally { $reader.Dispose() }
        [IO.File]::WriteAllText((Join-Path $destination 'Other/preserved-asset.txt'), 'exported asset')
        $canvas = Join-Path $destination 'CanvasApps'
        foreach ($name in $fixture.apps) {
            [IO.Directory]::CreateDirectory($canvas) | Out-Null
            $msapp = "${name}_DocumentUri.msapp"
            [IO.File]::WriteAllText((Join-Path $canvas $msapp), ($fixture | ConvertTo-Json))
            $xmlName = [Security.SecurityElement]::Escape($name)
            [IO.File]::WriteAllText((Join-Path $canvas "$name.meta.xml"), "<CanvasApp><Name>$xmlName</Name><DocumentUri>/CanvasApps/$msapp</DocumentUri></CanvasApp>")
        }
        if ($fixture.unmapped) { [IO.Directory]::CreateDirectory($canvas) | Out-Null; [IO.File]::WriteAllText((Join-Path $canvas 'unmapped.msapp'), 'orphan') }
    } finally { $zip.Dispose() }
    exit 0
}
if ($args[0] -eq 'canvas') {
    if ((Argument '--layout') -ne 'SourceCode') { throw 'Wrong Canvas layout' }
    $fixture = Get-Content -LiteralPath (Argument '--msapp') -Raw | ConvertFrom-Json -AsHashtable
    if ($fixture.failCanvas) { Write-Output 'injected Canvas failure'; exit 8 }
    $destination = Argument '--sources'
    $src = Join-Path $destination 'Src'
    [IO.Directory]::CreateDirectory((Join-Path $src 'Components')) | Out-Null
    if (-not $fixture.missingApp) { [IO.File]::WriteAllText((Join-Path $src 'App.pa.yaml'), "App:`n  Properties: {}`n") }
    [IO.File]::WriteAllText((Join-Path $src 'Components/component.pa.yaml'), "ComponentDefinitions: {}`n")
    [IO.File]::WriteAllText((Join-Path $destination 'intermediate.msapr'), 'do not track')
    if ($fixture.extraFile) { [IO.File]::WriteAllText((Join-Path $src 'unexpected.txt'), 'unexpected') }
    exit 0
}
throw "Unexpected fake PAC command: $($args -join ' ')"
