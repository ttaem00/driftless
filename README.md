# Driftless

**Overnight self-improving maintainer automation for Claude AND Codex.**

> [한국어 README](./README.ko.md) · [English (this page)]

[![CI](https://github.com/mizan0515/driftless/actions/workflows/gates.yml/badge.svg)](https://github.com/mizan0515/driftless/actions/workflows/gates.yml)
[![containment](https://img.shields.io/badge/containment-PASS-2ea44f)](./docs/en/guardrails.md)
[![mirror-parity](https://img.shields.io/badge/mirror--parity-PASS-2ea44f)](./docs/en/single-source-mirror.md)
[![version](https://img.shields.io/badge/version-v0.1.0-blue)](#changelog)
[![license](https://img.shields.io/badge/license-MIT-blue)](./LICENSE)
[![built itself](https://img.shields.io/badge/built%20itself-113%20PRs%20%2F%2094%20issues%20%2F%20114%20commits-6f42c1)](#this-repo-built-itself)

Paste one prompt before bed. Wake up to merged pull requests. You never have to write code.

> **v0.1.0, released today.** This repo's own star/PR graph grows from zero, in
> the open — judge it by cloning it and running the gates, not by a star count.
> The method is already proven: it maintains itself
> ([how the loop ran on its own backlog](./evidence/loop-log.md)), and what's
> verified on which OS is stated honestly in the
> [host evidence matrix](./docs/en/host-evidence-matrix.md).

## 60-second proof

*(See a real captured run: [examples/demo-transcript.txt](./examples/demo-transcript.txt) — clone -> install dry-run -> gates PASS.)*

**You need two things first:** [git](https://git-scm.com/downloads) and one agent
CLI — [Claude Code](https://docs.anthropic.com/claude-code) or
[OpenAI Codex](https://developers.openai.com/codex) — installed. Driftless drives
an agent; it does not replace one.

**1. Get the repo, then apply it** (run these in a terminal):

```sh
git clone https://github.com/mizan0515/driftless
cd driftless
sh ./install.sh        # macOS / Linux  (interactive: Claude, Codex, or both)
```
```powershell
git clone https://github.com/mizan0515/driftless
cd driftless
.\install.ps1          # Windows PowerShell
```

The installer builds an isolated agent home **inside this repository**. It never
touches your machine's global agent settings for either tool, and it installs
nothing else without asking you first (the answer defaults to "no").

**2. Watch it work.** Open your agent and paste one parent prompt — "push every
remaining ticket as far as you can overnight." The parent reads the open
issues, splits them into conflict-aware tickets, runs workers in parallel, and
turns them into branches and pull requests while you sleep. In the morning you
review merged PRs, not raw code. (Use the full prompt — which tells the agent to
*ask before anything risky, irreversible, or that costs money* — from
[quickstart Step 4](./docs/en/quickstart.md#step-4--paste-one-prompt-30-sec).)

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

## It gets better on its own (the five-axis gradient)

"Self-improving" here is concrete, not a slogan. Every recurring mistake is
promoted up an enforced ladder — **memory < skill < hot rule < hook < gate** —
until re-introducing it FAILs a check (see
[the lesson-promotion ladder](./docs/en/lesson-promotion-ladder.md), with a real
worked example). And the whole system is tuned to push five measured axes *down*
over time, because all five are forms of burden on you:

| Axis | What it means for you |
|---|---|
| **Tokens** | cheaper runs |
| **Your interventions** | fewer questions back to you |
| **Time** | faster to merged |
| **Money** | lower cost per merged PR |
| **Correctness** | fewer re-do loops |

A static, no-paid-LLM harness scores skill changes on these axes and rejects
regressions before they ship (`scripts/Test-SkillOptValidationHarness.ps1`; see
[evidence/5-axis-roi](./evidence/5-axis-roi/)). The point isn't more output — it
is less of your time, attention, and money spent each run.

## Works with Claude Code and OpenAI Codex

This is depth and safety on two tools, not a breadth checklist. The shared tier
(rules, skills, schemas, gates) is authored once; each profile runs it isolated
under its own config home. The agent ecosystem is built on shared open standards
(MCP, AGENTS.md), so running both is **ecosystem leverage** — not split loyalty.
See [single-source mirror](./docs/en/single-source-mirror.md).

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

A work-discipline gate keeps the *evidence-first* discipline mechanical, not
just prose: it FAILs if an unresolved placeholder (`TODO:` / `FIXME:` /
`<PLACEHOLDER>`) ships inside a tracked rule file, so an unfinished stub can
never land as if it were authoritative. A built-in self-test proves it FAILs on
a planted placeholder and PASSes clean. It also reports an advisory check that
the working branch follows `agent/issue-<n>-<slug>`:

```powershell
.\scripts\Test-WorkDiscipline.ps1            # full check on a clean tree
.\scripts\Test-WorkDiscipline.ps1 -SelfTest  # prove the detector has teeth
```

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
- **16** starter agent skills shipped in this public kit (1 Claude-specific,
  1 Codex-specific, 12 shared, plus 2 standalone — `overnight-autonomous-work`
  and `skillopt`); count them yourself with
  `git ls-files | grep -c SKILL.md`. The private development runtime it grew
  from carries more (39 Claude + 34 Codex) — those are dev-runtime counts, not
  what this repo ships
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

- [5-minute quickstart](./docs/en/quickstart.md) (non-developer; KO: [빠른 시작](./docs/ko/빠른시작.md)) — install -> one prompt -> morning report.

- [What is Driftless](./docs/en/what-is-driftless.md) — the idea in plain language.
- [Apply it to your own agent](./docs/en/apply-to-your-agent.md) — adopt the pieces you want.
- [Mission Map](./docs/en/mission-map.md) — public-safe fixture/spec for showing active goal, guardian, PR/check state, blockers, and next action.
- [Single-source two-profile mirror](./docs/en/single-source-mirror.md) — how one edit updates both.
- [Guardrails](./docs/en/guardrails.md) — containment, the forbidden surface, and the FAIL test.
- [Lesson-promotion ladder](./docs/en/lesson-promotion-ladder.md) — memory < skill < hot rule < hook < gate.
- [Host evidence matrix](./docs/en/host-evidence-matrix.md) — what is proven on which operating system.

## Who maintains this

A human operator-architect ([@mizan0515](https://github.com/mizan0515)) directs
the loop and owns every product, release, and irreversible decision; the AI
agents this project ships do the implementation labor under that direction,
behind containment and human-only gates. See [MAINTAINERS.md](./MAINTAINERS.md).

Small modular pieces you own — not a heavy framework. MIT licensed.
