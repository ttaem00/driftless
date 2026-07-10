# Wuther Codemap example

`school-media-repository/` is a synthetic unfamiliar repository. Its four small
Python modules and `codemap.json` contain no real organization, account, user,
or runtime data.

From the Driftless repository root:

```powershell
$example = '.\examples\wuther-codemap\school-media-repository'
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-WutherCodemap.ps1 `
  -Root $example -ManifestPath codemap.json -Clean
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-WutherCodemap.ps1 `
  -Root $example -ManifestPath codemap.json -Check
```

The three views appear under
`school-media-repository/.runtime/wuther-codemap/`. The thin PowerShell facade
uses the canonical Python generator and `jsonschema`. The focused test plants
schema, private-path, containment, ownership, and junction failures dynamically.
