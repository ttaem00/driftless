# Driftless

**Overnight self-improving maintainer automation for Claude AND Codex.**

> [한국어 README](./README.ko.md) · [English (this page)]

[![CI](https://img.shields.io/badge/CI-passing-2ea44f)](https://github.com/mizan0515/driftless/actions)
[![containment](https://img.shields.io/badge/containment-PASS-2ea44f)](./docs/en/guardrails.md)
[![mirror-parity](https://img.shields.io/badge/mirror--parity-PASS-2ea44f)](./docs/en/single-source-mirror.md)
[![version](https://img.shields.io/badge/version-v0.1.0-blue)](#changelog)
[![license](https://img.shields.io/badge/license-MIT-blue)](./LICENSE)
[![built itself](https://img.shields.io/badge/built%20itself-113%20PRs%20%2F%2094%20issues%20%2F%20114%20commits%20%2F%2073%20skills-6f42c1)](#this-repo-built-itself)

Paste one prompt before bed. Wake up to merged pull requests. You never have to write code.

## 60-second proof

**1. Apply it** (run once, inside the repo you cloned):

```sh
./install.sh           # macOS / Linux  (interactive: Claude, Codex, or both)
```
```powershell
.\install.ps1          # Windows PowerShell
```

The installer builds an isolated agent home **inside this repository**. It never
touches your machine's global agent settings for either tool, and it installs
nothing else without asking you first (the answer defaults to "no").

**2. Watch it work.** Open your agent and paste one parent prompt — "push every
remaining ticket as far as you can overnight." The parent reads the open
issues, splits them into conflict-aware tickets, runs workers in parallel, and
turns them into branches and pull requests while you sleep. In the morning you
review merged PRs, not raw code.

## One edit -> both profiles

Driftless is one repository with two isolated agent profiles side by side —
Claude and Codex — that consume **one shared tier**. Edit a shared rule, skill,
or schema once, and both profiles get it. A gate turns that promise into a
machine check instead of human memory:

```powershell
.\scripts\Test-ProfileMirrorParity.ps1
```

It FAILs the moment the two profiles drift apart, so they never silently
diverge. That is what *driftless* means: the profiles never split, and the
agent never wanders off your goal.

## Works with Claude Code and OpenAI Codex

This is depth and safety on two tools, not a breadth checklist. The shared tier
(rules, skills, schemas, gates) is authored once; each profile runs it isolated
under its own config home. OpenAI's open-source agent program is tool-agnostic,
and OpenAI co-founds open agent standards with Anthropic (MCP + AGENTS.md), so
running both is **ecosystem leverage** — not split loyalty. See
[single-source mirror](./docs/en/single-source-mirror.md).

## Guardrails at a glance

A containment gate proves the repo never reads or writes a forbidden path and
never leaks a credential — environment-secret files, SSH key directories,
secret stores, private keys, browser profiles, and the host-global agent home
directories for either tool:

```powershell
.\scripts\Test-Containment.ps1
```

Plant one violation — reference a host-global agent home or commit a key — and
the gate returns **FAIL**, blocking the change before it ships. The forbidden
surface is declared in one shared contract that both profiles consume. Details:
[guardrails](./docs/en/guardrails.md).

## Built by the loop it ships

Driftless is the public extract of a runtime that ran this exact overnight loop
**on its own backlog**: a non-developer gave goals in plain language, and the
agent did the git, GitHub, issue/PR, and validation mechanics. Issues became
branches, branches became pull requests, pull requests got reviewed and merged.

Measured on that development runtime at extraction (the proof the method works,
not a claim about this repo's star count):

- **113** merged pull requests
- **94** issues
- **114** commits
- **73** agent skills (39 Claude + 34 Codex)
- a dated decision register recording every manager and agent decision with its
  rationale

This public repository is **v0.1.0, day one** — its own pull-request and issue
graph starts now and grows as the loop runs here in the open. The point is not
"look how many stars": it is that the loop is real enough to maintain itself.
Watch this repo's history fill in: [commits](https://github.com/mizan0515/driftless/commits/main) ·
[pull requests](https://github.com/mizan0515/driftless/pulls) ·
[issues](https://github.com/mizan0515/driftless/issues).

## Changelog

- **2026-06-01 — v0.1.0** — First public cut. Two-profile single-source mirror,
  containment gate, mirror-parity gate, Windows text-safety gate, overnight
  autonomous-work and skillopt skills, and POSIX + PowerShell installers.

## Learn more

- [What is Driftless](./docs/en/what-is-driftless.md) — the idea in plain language.
- [Apply it to your own agent](./docs/en/apply-to-your-agent.md) — adopt the pieces you want.
- [Single-source two-profile mirror](./docs/en/single-source-mirror.md) — how one edit updates both.
- [Guardrails](./docs/en/guardrails.md) — containment, the forbidden surface, and the FAIL test.
- [Lesson-promotion ladder](./docs/en/lesson-promotion-ladder.md) — memory < skill < hot rule < hook < gate.
- [Host evidence matrix](./docs/en/host-evidence-matrix.md) — what is proven on which operating system.

Small modular pieces you own — not a heavy framework. MIT licensed.
