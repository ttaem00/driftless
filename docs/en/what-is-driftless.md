# What is Driftless?

**Driftless is overnight self-improving maintainer automation for Claude AND Codex.**

You paste one prompt before bed. While you sleep, an AI maintainer works through
your repository's backlog the way a careful teammate would: it reads the open
issues, decides what is safe to do on its own, makes the changes on branches,
opens pull requests, and merges the ones that pass every safety check. You wake
up to merged pull requests. **You never have to write code.**

> **Paste one prompt before bed. Wake up to merged pull requests.**

---

## The plain-language version

Most "AI coding" tools expect *you* to drive. You write the prompt, you read the
diff, you approve each step. That works if you are a developer. Driftless is for
the person who is **not** a developer and does not want to become one — a
manager who knows *what* should happen but not *how* to make a computer do it.

With Driftless you do three things:

1. **Say your goal once.** In plain language. "Keep the project healthy, finish
   the easy tickets, and ask me before anything risky."
2. **Go to sleep.** The AI maintainer runs on its own, inside strict safety
   fences (see [Guardrails](./guardrails.md)).
3. **Read a short morning report.** In your own language, starting with one of
   four clear labels: done, needs your decision, blocked, or in progress. The
   raw commands and links come *after* the plain summary, as evidence — never
   instead of it.

The maintainer is allowed to be autonomous, but only **within gates**. It can
fix, branch, and merge by itself. It cannot touch your private files, cannot
spend money, cannot publish anything to the world, and cannot do anything it
can't undo — those decisions always come back to you as a short question.

---

## Why it is called "Driftless"

A boat that has no anchor *drifts* — it wanders away from where you left it. Two
copies of the same document, edited separately, *drift apart* until they
disagree. AI agents *drift* too: left alone, they wander off the goal you gave
them and start "improving" things you never asked about.

**Driftless means two kinds of not-wandering:**

1. **The two tool profiles never diverge.** Driftless runs both Claude Code and
   Codex from **one shared source of truth**. The safety rules, the vocabulary,
   and the shared skills live in exactly one place and both tools read it. Change
   it once and both improve at the same moment — there is no second copy to fall
   out of sync. (This is enforced by a mirror-parity gate, not just hoped for.)
2. **The agent never wanders off your goal.** Every overnight session re-reads
   your real intent, records its decisions with a reason, and refuses to call a
   job "done" while hidden, unverified, or risky work is still pending.

So "Driftless" is a promise about *staying put*: the two profiles stay aligned
with each other, and the agent stays aligned with you.

---

## Multi-tool is a feature, not a hedge

Driftless supports Claude **and** Codex on purpose. This is not splitting your
attention between two tools — it is using the strengths of each:

- **Claude Code** is excellent at the build-and-fix half: writing changes,
  reasoning through a codebase, orchestrating its own helper sessions overnight.
- **Codex** (`goal` mode) is well suited to the review-and-release half: checking
  pull requests, gating releases.

The open agent ecosystem is deliberately tool-agnostic — shared standards like
**MCP** and **AGENTS.md** are co-developed across the industry — so a project
that speaks both is using **ecosystem leverage**, not betting on one vendor.
Driftless's single-source mirror means supporting a second tool costs you almost
nothing: the shared half is written once.

---

## The technical layer

If you *are* technical, here is what is under the hood. Everything below is
plain-language above; this section just names the machinery.

### 1. Single source, two profiles

```
driftless/
├── profiles/
│   ├── shared/     <- the one source of truth: design contract, safety
│   │                  schemas, tool-agnostic skills (read by BOTH tools)
│   ├── claude/     <- Claude Code profile (shared + Claude-specific)
│   └── codex/      <- Codex profile (shared + Codex-specific)
```

A built profile is **shared + tool-specific**. Anything identical for both tools
(forbidden-path rules, evidence vocabulary, shared skills) lives in `shared/`
**once**; each profile adds only what is genuinely different (launcher mechanics,
the hot-rules filename — `CLAUDE.md` vs `AGENTS.md` — skill format, model
defaults). A **mirror-parity gate** verifies the two profiles never drift apart.

### 2. Five-axis gradient descent

Driftless does not optimize for "more output." It pushes five measurable axes
*down* over time, the way you slide down a hill toward the lowest point:

| Axis | What it means | Goal |
|---|---|---|
| **Tokens** | How much the AI reads/writes per task | lower |
| **Manager intervention** | How often it has to ask you | lower |
| **Time** | How long a task takes | lower |
| **Money** | Usage cost (for subscription plans, this is requests/sessions, not dollars) | lower |
| **Performance** | Whether the work is actually correct | higher |

Each session leaves telemetry so the trend is visible, not guessed.

That applies to Driftless itself, not only to the projects it maintains. A
skill, hook, script, prompt, hot rule, doc, gate, installer, or report format is
an optimization surface when changing it can reduce tokens, your interventions,
time, or usage cost without weakening correctness. Shared improvements land once
in `profiles/shared/` so Claude and Codex both get them. Tool-specific mistakes
stay tool-specific: Codex goal-mode lessons stay in the Codex profile, while
Claude ultracode/workflow lessons stay in the Claude profile. The system should
detect, measure, rank, and ticket these opportunities automatically; risky
changes still pass through the same validation gates.

### 3. An enforced lesson-promotion ladder

When the maintainer learns a lesson, the lesson does not just sit in a memory
note (which is easy to forget). It is **promoted** to a stronger surface based on
how badly things break if it is ignored:

```
memory note  <  on-demand skill  <  hot rule  <  hook  <  gate script
   (weakest: recall-only)              (strongest: machine-enforced, blocks merge)
```

A lesson whose recurrence would cause an irreversible, security, or
false-"done" mistake is pushed all the way to a **gate script** — a check that
*mechanically fails* the work until the lesson is honored. The system gets harder
to break the more it learns.

### 4. A containment guard that never touches your private files

A static containment guard scans every change and FAILs if any file's own path is
forbidden, references a forbidden path, or contains a credential token. It never
reads or mutates the host-global `~/.claude` or `~/.codex`, `.env` files, SSH
keys, browser profiles, or anything secret. See [Guardrails](./guardrails.md) and
[Host Evidence Matrix](./host-evidence-matrix.md).

---

## This product built itself

Driftless is not a demo. The runtime it grew out of used this exact overnight
loop on its **own** repository: issues became branches, branches became pull
requests, pull requests were reviewed and merged — driven by the autonomous
maintainer, with a non-developer manager approving only the gated decisions. The
measured history of that source repository:

- **113 merged pull requests**
- **94 issues**
- **114 commits**
- **39 Claude skills + 34 Codex skills** across the two profiles *in that
  development runtime* (this public kit ships 14 profile starter skills — `find profiles
  -name SKILL.md | wc -l`)
- A static containment guard that passes on a clean tree, a Windows text-safety
  gate enforcing ASCII + no-BOM scripts, and a profile mirror-parity gate
- A dated decision register recording both manager decisions and agent decisions
  with a reason for each

That is the point: the loop is real enough to maintain itself.

---

## Where to go next

- **[Guardrails](./guardrails.md)** — the safety fences that make "autonomous
  overnight" safe.
- **[Host Evidence Matrix](./host-evidence-matrix.md)** — exactly which operating
  systems are verified, and which are honestly still unverified.
- Korean: **[드리프트리스란?](../ko/드리프트리스란.md)**
