#requires -Version 7.0
#requires -PSEdition Core
[CmdletBinding()]
param(
  [string]$Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,
  [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Add-Result {
  param([System.Collections.Generic.List[object]]$Rows, [string]$Check, [bool]$Passed, [string]$Evidence)
  $Rows.Add([pscustomobject]@{
      check = $Check
      status = if ($Passed) { 'PASS' } else { 'FAIL' }
      evidence = $Evidence
    }) | Out-Null
}

function Invoke-Wuther {
  param([string[]]$Arguments)
  $saved = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $output = @(& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $invoke @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $saved
  }
  [pscustomobject]@{ exit = $exitCode; output = @($output | ForEach-Object { [string]$_ }) }
}

$repoRoot = (Resolve-Path -LiteralPath $Root).Path
$invoke = Join-Path $repoRoot 'scripts\Invoke-WutherCodemap.ps1'
$fixtureSource = Join-Path $repoRoot 'examples\wuther-codemap\school-media-repository'
$skillPath = Join-Path $repoRoot 'profiles\shared\skills\wuther-codemap\SKILL.md'
$vectorPath = Join-Path $repoRoot 'examples\wuther-codemap\canonical-v1-vector.json'
$testBase = Join-Path $repoRoot '.runtime\test-wuther-codemap'
$testRoot = Join-Path $testBase ([guid]::NewGuid().ToString('N'))
$fixtureRoot = Join-Path $testRoot 'repository'
$outputRelative = '.runtime/wuther-codemap'
$outputFull = Join-Path $fixtureRoot $outputRelative
$results = [System.Collections.Generic.List[object]]::new()
$outside = $null
$junction = $null

try {
  New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
  Copy-Item -Path (Join-Path $fixtureSource '*') -Destination $fixtureRoot -Recurse -Force

  $build = Invoke-Wuther @('-Root', $fixtureRoot, '-ManifestPath', 'codemap.json', '-OutputPath', $outputRelative, '-Clean', '-Json')
  $files = @('manager.html', 'llm-context.json', 'llm-context.md')
  $complete = $build.exit -eq 0 -and @($files | Where-Object { -not (Test-Path -LiteralPath (Join-Path $outputFull $_)) }).Count -eq 0
  Add-Result $results 'canonical build' $complete 'three manager and LLM artifacts generated'

  $context = Get-Content -LiteralPath (Join-Path $outputFull 'llm-context.json') -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
  $contractComplete = $context.schema_version -eq 'wuther-codemap.v1' -and @($context.nodes).Count -eq 4 -and @($context.data_objects).Count -eq 5 -and @($context.edges).Count -eq 3
  Add-Result $results 'one canonical contract' $contractComplete 'schema_version, nodes, data_objects, and edges share the private/public v1 shape'

  $html = Get-Content -LiteralPath (Join-Path $outputFull 'manager.html') -Raw -Encoding UTF8
  $truthfulFlow = $html.Contains("MODEL.edges.map") -and -not $html.Contains('.node:after')
  Add-Result $results 'edge-driven manager flow' $truthfulFlow 'visual connections are derived from MODEL.edges rather than array order'

  $check = Invoke-Wuther @('-Root', $fixtureRoot, '-ManifestPath', 'codemap.json', '-OutputPath', $outputRelative, '-Check')
  Add-Result $results 'deterministic check' ($check.exit -eq 0) 'fresh artifacts pass read-only check mode'

  $sentinel = Join-Path $outputFull 'manager-note.txt'
  [System.IO.File]::WriteAllText($sentinel, 'unowned', [System.Text.UTF8Encoding]::new($false))
  $rebuild = Invoke-Wuther @('-Root', $fixtureRoot, '-ManifestPath', 'codemap.json', '-OutputPath', $outputRelative, '-Clean')
  Add-Result $results 'owned-only clean' ($rebuild.exit -eq 0 -and (Test-Path -LiteralPath $sentinel)) 'clean regenerated owned artifacts and preserved an unowned manager file'

  $invalid = Get-Content -LiteralPath (Join-Path $fixtureRoot 'codemap.json') -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
  $invalid.nodes[0].id = 'INVALID ID'
  $invalid.edges[0].from = 'INVALID ID'
  $invalid.data_objects[0].fields[0].PSObject.Properties.Remove('meaning')
  $invalidPath = Join-Path $fixtureRoot 'invalid-schema.json'
  $invalid | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $invalidPath -Encoding UTF8
  $invalidRun = Invoke-Wuther @('-Root', $fixtureRoot, '-ManifestPath', 'invalid-schema.json', '-OutputPath', '.runtime/invalid-schema')
  Add-Result $results 'schema authority negative case' ($invalidRun.exit -ne 0) 'unstable id and missing field meaning were rejected'

  $validBytes = [System.IO.File]::ReadAllBytes((Join-Path $outputFull 'manager.html'))
  $validHash = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($validBytes))
  $failedClean = Invoke-Wuther @('-Root', $fixtureRoot, '-ManifestPath', 'invalid-schema.json', '-OutputPath', $outputRelative, '-Clean')
  $preservedBytes = [System.IO.File]::ReadAllBytes((Join-Path $outputFull 'manager.html'))
  $preservedHash = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($preservedBytes))
  Add-Result $results 'failed clean preserves valid output' ($failedClean.exit -ne 0 -and $validHash -eq $preservedHash) 'replacement validation happens before owned artifacts are replaced'

  $private = Get-Content -LiteralPath (Join-Path $fixtureRoot 'codemap.json') -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
  $private.nodes[0].code_refs[0].path = ('C:' + [char]92 + 'Users' + [char]92 + 'private-user' + [char]92 + '.' + 's' + 'sh' + [char]92 + 'id_rsa')
  $privatePath = Join-Path $fixtureRoot 'private-path.json'
  $private | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $privatePath -Encoding UTF8
  $privateRun = Invoke-Wuther @('-Root', $fixtureRoot, '-ManifestPath', 'private-path.json', '-OutputPath', '.runtime/private-path')
  Add-Result $results 'private-path negative case' ($privateRun.exit -ne 0) 'host-global private path was rejected before rendering'

  $posix = Get-Content -LiteralPath (Join-Path $fixtureRoot 'codemap.json') -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
  $posix.nodes[0].code_refs[0].path = ('/' + 'etc' + '/' + 'passwd')
  $posixPath = Join-Path $fixtureRoot 'posix-path.json'
  $posix | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $posixPath -Encoding UTF8
  $posixRun = Invoke-Wuther @('-Root', $fixtureRoot, '-ManifestPath', 'posix-path.json', '-OutputPath', '.runtime/posix-path')
  Add-Result $results 'absolute POSIX path negative case' ($posixRun.exit -ne 0) 'code_refs paths must be repository-relative'

  $relativeEscapesOk = $true
  foreach ($unsafePath in @('~/' + 'private.py', 'file' + ':/etc/passwd')) {
    $relativeEscape = Get-Content -LiteralPath (Join-Path $fixtureRoot 'codemap.json') -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
    $relativeEscape.nodes[0].code_refs[0].path = $unsafePath
    $relativeEscapePath = Join-Path $fixtureRoot ('relative-escape-' + [guid]::NewGuid().ToString('N') + '.json')
    $relativeEscape | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $relativeEscapePath -Encoding UTF8
    $relativeEscapeRun = Invoke-Wuther @('-Root', $fixtureRoot, '-ManifestPath', $relativeEscapePath, '-OutputPath', '.runtime/relative-escape')
    if ($relativeEscapeRun.exit -eq 0) { $relativeEscapesOk = $false }
  }
  Add-Result $results 'home and URI path negative cases' $relativeEscapesOk 'home shorthand and URI-scheme code references were rejected'

  $edgeMismatch = Get-Content -LiteralPath (Join-Path $fixtureRoot 'codemap.json') -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
  $edgeMismatch.nodes[1].data_in = @('lesson_record')
  $edgePath = Join-Path $fixtureRoot 'edge-mismatch.json'
  $edgeMismatch | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $edgePath -Encoding UTF8
  $edgeRun = Invoke-Wuther @('-Root', $fixtureRoot, '-ManifestPath', 'edge-mismatch.json', '-OutputPath', '.runtime/edge-mismatch')
  Add-Result $results 'edge and node contract consistency' ($edgeRun.exit -ne 0) 'edge data must exist in source data_out and target data_in'

  $alternateSchemaRun = Invoke-Wuther @('-Root', $fixtureRoot, '-ManifestPath', 'codemap.json', '-OutputPath', '.runtime/alternate-schema', '-SchemaPath', 'codemap.json')
  Add-Result $results 'canonical schema binding' ($alternateSchemaRun.exit -ne 0) 'public facade does not accept an alternate schema'

  $outside = Join-Path $testRoot 'outside'
  $outsideRun = Invoke-Wuther @('-Root', $fixtureRoot, '-ManifestPath', 'codemap.json', '-OutputPath', $outside)
  Add-Result $results 'root containment' ($outsideRun.exit -ne 0 -and -not (Test-Path -LiteralPath $outside)) 'outside output was rejected'

  $docsSentinel = Join-Path $fixtureRoot 'README.md'
  $docsBytes = [System.IO.File]::ReadAllBytes($docsSentinel)
  $docsRun = Invoke-Wuther @('-Root', $fixtureRoot, '-ManifestPath', 'codemap.json', '-OutputPath', '.', '-Clean')
  $docsStable = [System.Linq.Enumerable]::SequenceEqual([byte[]]$docsBytes, [byte[]][System.IO.File]::ReadAllBytes($docsSentinel))
  Add-Result $results 'existing directory ownership' ($docsRun.exit -ne 0 -and $docsStable) 'repository root without a Wuther marker was rejected and unchanged'

  $outside = Join-Path ([System.IO.Path]::GetTempPath()) ('wuther-outside-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $outside -Force | Out-Null
  $junction = Join-Path $fixtureRoot '.runtime\junction-output'
  New-Item -ItemType Junction -Path $junction -Target $outside | Out-Null
  $junctionRun = Invoke-Wuther @('-Root', $fixtureRoot, '-ManifestPath', 'codemap.json', '-OutputPath', '.runtime/junction-output')
  Add-Result $results 'junction containment' ($junctionRun.exit -ne 0) 'junction-backed output was rejected'

  $skill = Get-Content -LiteralPath $skillPath -Raw -Encoding UTF8
  Add-Result $results 'exact cross-agent trigger' ($skill.Contains('name: wuther-codemap') -and $skill.Contains('wuther-codemap,')) 'shared skill exposes the exact trigger'

  $vector = Get-Content -LiteralPath $vectorPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $vectorFiles = [ordered]@{
    manifest_sha256 = (Join-Path $fixtureRoot 'codemap.json')
    schema_sha256 = (Join-Path $repoRoot 'profiles\shared\schemas\wuther-codemap-manifest.schema.json')
    generator_sha256 = (Join-Path $repoRoot 'tools\wuther-codemap\generate.py')
  }
  $vectorOk = $true
  foreach ($property in $vectorFiles.Keys) {
    $text = [System.IO.File]::ReadAllText($vectorFiles[$property]) -replace "`r`n", "`n"
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($text)
    $actual = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
    if ($actual -ne [string]$vector.$property) { $vectorOk = $false }
  }
  foreach ($property in $vector.outputs.PSObject.Properties) {
    $text = [System.IO.File]::ReadAllText((Join-Path $outputFull $property.Name)) -replace "`r`n", "`n"
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($text)
    $actual = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
    if ($actual -ne [string]$property.Value) { $vectorOk = $false }
  }
  Add-Result $results 'fixed canonical release vector' $vectorOk 'schema, generator, manifest, and all three output digests match v1'
} catch {
  Add-Result $results 'test harness' $false $_.Exception.Message
} finally {
  if ($junction -and (Test-Path -LiteralPath $junction)) { Remove-Item -LiteralPath $junction -Force }
  if ($outside -and (Test-Path -LiteralPath $outside)) { Remove-Item -LiteralPath $outside -Recurse -Force }
  if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
  if ((Test-Path -LiteralPath $testBase) -and @(Get-ChildItem -LiteralPath $testBase -Force).Count -eq 0) {
    Remove-Item -LiteralPath $testBase -Force
  }
}

Add-Result $results 'test artifact cleanup' (-not (Test-Path -LiteralPath $testRoot)) 'unique test directory removed'
$failures = @($results | Where-Object status -ne 'PASS')
$summary = [ordered]@{
  gate = 'wuther-codemap'
  status = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }
  pass = @($results | Where-Object status -eq 'PASS').Count
  fail = $failures.Count
  results = @($results)
}
if ($Json) {
  $summary | ConvertTo-Json -Depth 8
} else {
  Write-Output '== Wuther Codemap test =='
  foreach ($row in $results) { Write-Output ("[{0}] {1} - {2}" -f $row.status, $row.check, $row.evidence) }
  Write-Output ("RESULT: {0} (pass={1} fail={2})" -f $summary.status, $summary.pass, $summary.fail)
}
if ($failures.Count -gt 0) { exit 1 }
exit 0
