# Wuther Codemap

The private and public packages use the same canonical
`schema_version: wuther-codemap.v1` contract and generator.

Wuther Codemap gives a non-developer maintainer and an AI agent the same map of
an unfamiliar repository. You review one versioned JSON manifest; Driftless
then generates three views without a hosted service or renderer dependency:

- `manager.html`: easy mode, edge-driven data flow, domains, purpose-first
  nodes, connections, and data lifecycle;
- `llm-context.json`: structured facts for tools and agents;
- `llm-context.md`: compact context for prompts and reviews.

## Try the public fixture

From the Driftless repository root:

```powershell
$example = '.\examples\wuther-codemap\school-media-repository'
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-WutherCodemap.ps1 `
  -Root $example -ManifestPath codemap.json -Clean
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-WutherCodemap.ps1 `
  -Root $example -ManifestPath codemap.json -Check
```

Open
`examples/wuther-codemap/school-media-repository/.runtime/wuther-codemap/manager.html`.
The same output folder contains the two LLM views.

## Map another repository

1. Copy the example `codemap.json` into the target repository.
2. Replace the synthetic facts after inspecting the listed source files.
3. Keep repo-relative `code_refs`, each node's purpose, risks, validation,
   inputs and outputs, and every data object's shape, origin, transformation,
   storage, consumers, validation, and missing impact.
4. Run the generator with the target repository as `-Root`.
5. Run `-Check` whenever source structure or the manifest changes.

The schema is
`profiles/shared/schemas/wuther-codemap-manifest.schema.json`. It rejects maps
that omit required meaning, code provenance, risks, validation, or data
lifecycle fields. The generator also rejects duplicate IDs, broken node/domain/
data references, cycles, private host paths, manifests outside the target root,
and symlink or junction output escapes.

## Output and cleanup

The default output is `.runtime/wuther-codemap` under the selected repository.
`-Check` is read-only and fails on missing or stale owned output. `-Clean`
removes only the three Wuther-owned artifacts, preserves unrelated files, and
writes one fresh set. A marker prevents generation into an existing unowned
directory. The canonical Python renderer uses the `jsonschema` package;
optional renderers may consume `llm-context.json` without replacing the model.

Run the focused proof:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-WutherCodemap.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-InstallerMaterialization.ps1
```

`examples/wuther-codemap/canonical-v1-vector.json` fixes the schema, generator,
fixture, and three output digests. Silent private/public contract drift fails
before release.

The second command materializes shared skills into both repo-local homes and
checks that Codex and Claude discover the exact `wuther-codemap` trigger. It
never reads or writes a host-global agent profile.
