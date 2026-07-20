---
name: wuther-codemap
description: >
  wuther-codemap: Generate a public-safe repository map from one versioned
  manifest for both non-developer maintainers and AI agents. Use when asked for
  wuther-codemap, a portable code map, repository data flow/domains/nodes,
  connection meaning, code provenance, or a manager HTML plus LLM
  JSON/Markdown view of an unfamiliar repository.
---
## Improvement Principle

Use root-cause analysis and root-cause fixes, not symptom patches. Generalize
as principle-based guidance or design principles; avoid spec/case overfitting
and special-casing unless evidence proves a bounded exception reduces user
effort, maintainer effort, maintenance risk, or safety burden.

# Wuther Codemap

Generate all views from one reviewed manifest. Do not infer private runtime
state, credentials, browser data, or unlisted source facts.

## Workflow

1. Resolve the target repository root and inspect only the source paths needed
   to describe its purpose, domains, purpose-first nodes, data edges, code
   references, and data lifecycle.
2. Copy `examples/wuther-codemap/school-media-repository/codemap.json` into the
   target repository and replace the synthetic facts with source-backed facts.
3. Keep `schema_version: wuther-codemap.v1`, repo-relative `code_refs`,
   node risks and validation, edge data IDs, and every data object's complete
   lifecycle. Use plain manager language.
4. Generate the views with the repo-local facade:

   ```powershell
   pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-WutherCodemap.ps1 -Root <target-repo> -ManifestPath codemap.json -Clean
   ```

5. Re-run with `-Check` before reporting the map current. A failed check means
   the manifest or generated views drifted; regenerate with `-Clean`.
6. Open `.runtime/wuther-codemap/manager.html` for the maintainer. Give AI
   agents `.runtime/wuther-codemap/llm-context.json` or `llm-context.md`.

## Boundaries

- Treat the manifest as the only model for all generated views.
- Keep output under the selected repository root in an empty or Wuther-marked
  directory. Clean only Wuther-owned files; never clean a source directory.
- Keep the built-in renderer as the default. External visualization tools may
  consume `llm-context.json`, but they are optional and never required to build
  the manager view.
- Preserve code provenance and data contracts. Mark unknown facts plainly instead
  of inventing certainty.
- Do not include credentials, private paths, browser state, active session IDs,
  or organization-specific history in a public map.

## Evidence

Report the manifest path, the three generated files, the `-Check` result, and
any facts that remain `UNVERIFIED`. Use `Test-WutherCodemap.ps1` for the bundled
positive, negative, boundary, cleanup, and installation checks.

## Bootstrap, edit, and freshness gate

Use four explicit modes: `bootstrap` creates or opens the map, `impact` names
affected nodes before an edit, `verify` regenerates and checks after the edit,
and `view` opens the manager or LLM output. A source revision mismatch makes
the map stale and blocks its use as edit context. The generated manager view
and LLM context must come from the same manifest and source revision.
