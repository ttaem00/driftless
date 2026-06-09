# Compiled Context Wiki

Driftless includes a lightweight, clean-room version of the compiled context wiki
pattern. It turns recurring repository context into a generated markdown wiki so
maintainers and agents can find decisions, guardrails, profile rules, and skills
without rereading the whole repository.

It is intentionally small:

- no GPL code copied from external desktop applications;
- no paid APIs, embeddings, web search, MCP server, or local HTTP service;
- no host-global agent profile, credential, browser profile, or private vault
  access;
- no generated context committed by default.

The source of truth remains the git-tracked repository files. The wiki is only a
speed layer generated under `.runtime/context-wiki`.

## Build

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File scripts\Build-RepoContextWiki.ps1
```

The output is Obsidian-friendly markdown:

```text
.runtime/context-wiki/
  wiki/index.md
  wiki/purpose.md
  wiki/schema.md
  wiki/log.md
  wiki/pages/*.md
  index/source-manifest.json
  index/search-index.json
  index/graph.json
```

## Search

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File scripts\Search-RepoContextWiki.ps1 -Query "Codex profile" -BuildIfMissing
```

Each match cites the real source file and generated wiki page.

## Validate

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File scripts\Test-RepoContextWiki.ps1
```

The validator builds a fresh test wiki and checks source traceability, graph
shape, search behavior, and generated wikilinks.

## Benchmark Before Installing Code-Intelligence Tools

Driftless also includes a public-safe benchmark gate:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File scripts\Test-CodeIntelligenceBenchmark.ps1 -Root .
```

The benchmark compares broad baseline discovery against the compiled wiki on
fixed Driftless tasks. It gates average recall, token-estimate direction, and
source-traceability validation before any external code-intelligence dependency
is treated as adoption-ready.

## Why This Fits Driftless

Driftless is about lowering maintainer burden without turning the maintainer
into a toolchain operator. A compiled wiki gives agents a cheap on-demand memory
map while preserving the existing containment model: public repo files in,
gitignored generated context out.
