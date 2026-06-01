# Codex and Claude: two tools, one shared core

Driftless runs **two** AI tools on the same repository — OpenAI Codex and Claude
Code — and they are not interchangeable. Each has a headline mode it is good at,
and Driftless leans on the right one for the right job. Underneath, both read
**one shared core**, so improving the shared half improves both at once.

This page makes the split explicit:

- [How **Codex** uses Driftless](#how-codex-uses-driftless) — the review-and-release half.
- [How **Claude** uses Driftless](#how-claude-uses-driftless) — the build-and-fix half.
- [The **shared core** both read](#the-shared-core-both-read) — one edit, both improve.
- [**Which tool for which job**](#which-tool-for-which-job) — a non-developer's cheat sheet.

> Honest framing: this is **v0.1.0, day one**. The split below describes how the
> two profiles are *designed* to be used. The autonomous loop itself ran on the
> source runtime's own repository; macOS remains UNVERIFIED (see
> [Host Evidence Matrix](./host-evidence-matrix.md)).

---

## How Codex uses Driftless

Codex's headline mode in Driftless is **goal mode**. You give it a clear goal and
verifiable success criteria, and the Codex session works toward that goal on its
own for longer — without checking back at every step. That shape fits the
**review-and-release** side of maintaining a repository, where the work is
well-scoped and the "done" signal is concrete.

What goal mode drives well:

- **Pull-request review** — read a PR, check it against the success criteria, and
  report what passes or what blocks merge. The "done" signal is concrete (mergeable,
  checks green, no risk gate), which is exactly what goal mode needs.
- **Issue triage** — work down a set of open issues, classify what is safe to do
  alone, and act on the runnable ones.
- **Release gating** — verify the conditions a release must meet before it ships.
- **Security and maintainer automation** — repeatable, well-defined checks where
  the criteria are written down up front.

How the Driftless Codex profile makes that work:

- **The goal-mode skill** (`profiles/codex/skills/goal-mode/SKILL.md`) holds the
  contract. You give it three lines — goal, success criteria, scope/exclusions —
  and the Codex session owns the rest: inventory, lane breakdown, execution,
  retries, the verification/merge/issue gates, and the final manager report. Only
  true manager-only decisions (product priority, billing, public release,
  irreversible actions, credentials) come back to you.
- **A success-criteria gate.** Goal mode refuses to run long on vague criteria.
  Each criterion must be *verifiable* — a passing command, a visible behavior, a
  merged PR, a closed issue — never prose like "it works well." Vague criteria plus
  long autonomy wastes time and tokens, so it tightens the criteria first.
- **Parallel-safe goal lanes.** Independent tickets — ones whose write surfaces do
  not overlap and that have no ordering dependency — fan out as separate worker
  goal lanes (one lane = one issue/branch).
- **A session-claim handshake** stops two lanes racing the same issue or branch:
  *check before you mutate, acquire on start, serialize on conflict, release when
  done.* A stale claim alone never counts as "this lane was attempted," and the
  re-check just before writing is what prevents lost work.
- **Empty output is never PASS.** A missing or empty result is `UNVERIFIED`, not
  success — the same evidence discipline the whole system uses.

> Cost note (honest): the longer-running Codex goal lanes — PR review, release
> automation — are the ones that consume API credits. Reports surface that cost
> axis instead of hiding it.

---

## How Claude uses Driftless

Claude's headline mode in Driftless is **ultracode** — two dials turned up at
once: **maximum (xhigh) reasoning effort** plus **dynamic multi-agent workflow
orchestration**, where Claude plans lanes and spawns its *own* subagents over this
repo's work, then reviews and adopts their output itself. That shape fits the
**build-and-fix** side, where the goal is large or ambiguous and a cheap wrong
first pass would cost more than the extra thinking.

What ultracode is good at:

- **Big, ambiguous goals** — multiple sub-problems, unclear scope, or a manager who
  said "do everything / push all of it / figure out what matters." The parent plans
  lanes, recovers failed ones, and reconciles before reporting.
- **Long-context cleanup** — reasoning across many files at once, where holding the
  whole picture in view matters.
- **Docs and design review** — writing and revising explanation, and applying the
  design guidance before any UI/layout/user-flow change.
- **The overnight loop** — the parent fans out independent lanes, recovers failures
  on its own, and only escalates the true manager-only decisions.

How the Driftless Claude profile makes that work:

- **The ultracode skill**
  (`profiles/claude/skills/ultracode-orchestration/SKILL.md`) is the contract for
  *when* to escalate and *how* to fan out. The discipline is **lean gradient**:
  spend the least effort that reliably answers the decision, and escalate one notch
  only when the cheap path would likely be wrong. A tiny, well-specified task stays
  single-agent and low-effort — over-orchestrating a small job is itself a defect.
- **The harness owns spawning.** In-session fan-out goes through the native workflow
  / subagent mechanism, which caps concurrency and gives native isolation. Claude
  never fakes parallelism with a raw batch of shell calls (one error cancels the
  whole batch), and never shells out to an external launcher.
- **Subagents are Claude on this repo's own work** — not peer AIs, not other CLIs,
  not bridges to other models. Self-orchestration is the allowed exception that
  ultracode *is*; spawning a peer or recursive external AI is not.
- **Worktree isolation with a sharp edge:** lanes that edit the *same* existing file
  run in isolated worktrees; lanes that *create new files* must not use a side
  worktree (new files made there are silently lost) — those are isolated by disjoint
  file paths in the shared checkout instead.
- **The parent re-verifies every worker output.** A lane ending at "review-ready" is
  not Done — the parent reviews the diff and evidence, re-runs the gates, and only
  then adopts, merges, or closes.

---

## The shared core both read

Codex and Claude are different paradigms **on purpose**, and Driftless does not try
to force one to mimic the other. Codex parallelizes through discrete goal lanes;
Claude parallelizes natively inside one harness. Neither port is "missing" the
other's wrapper — they solve the same underlying job their own way.

What they do **not** keep two copies of is the part that is genuinely the same:

- the **design contract** — the evidence vocabulary (PASS / FAIL / BLOCKED /
  UNVERIFIED / PARTIAL), the four manager report labels, the manager-only gates;
- the **forbidden-paths schema** — the one machine-readable safety surface both
  containment guards consume;
- the **tool-agnostic skills** — lane decomposition with a conflict matrix,
  finish-to-done, the overnight execution bundle.

That shared half lives once under `profiles/shared/`, and each profile reads it by
relative path. Edit a shared rule and **both** tools pick it up at the same moment
— there is no second copy to fall out of sync, and a **mirror-parity gate** turns
that promise into a machine check. The tool-specific halves (goal mode vs
ultracode, `AGENTS.md` vs `CLAUDE.md`, launcher mechanics, skill format) are
*expected* to differ and are not forced to match.

See [Single source, two profiles](./single-source-mirror.md) for exactly how the
one-edit-both-improve mirror works and how the gate enforces it.

---

## Which tool for which job

A plain cheat sheet for a non-developer. You usually do not pick by hand — you
state your goal and the loop routes it — but this is the underlying logic.

| Your situation | Reach for | Why |
|---|---|---|
| "Review this pull request before I merge it." | **Codex** (goal mode) | Well-scoped, concrete done-signal. |
| "Triage the open issues and do the safe ones." | **Codex** (goal mode) | Repeatable, criteria written up front. |
| "Gate the release / run the security checks." | **Codex** (goal mode) | Defined pass conditions. |
| "Do everything in the backlog overnight." | **Claude** (ultracode) | Large, ambiguous, fan-out parent. |
| "Clean up this messy area across many files." | **Claude** (ultracode) | Long-context reasoning. |
| "Write/revise the docs or review the design." | **Claude** (ultracode) | Writing and design judgment. |
| "Fix this one obvious typo." | **Either, low effort** | No fan-out, no xhigh — that would be overkill. |

**The one-line rule:** Codex when the goal and the "done" signal are already crisp;
Claude when the goal is big or fuzzy and someone has to figure out *what* done even
means. For anything small and obvious, neither tool escalates — the lean-gradient
rule says spend the least effort that reliably answers the question.

---

## Where to go next

- **[Single source, two profiles](./single-source-mirror.md)** — how one edit
  updates both tools, and the mirror-parity gate.
- **[What is Driftless?](./what-is-driftless.md)** — the full picture.
- **[Guardrails](./guardrails.md)** — the safety fences both tools run inside.
- The skills themselves: `profiles/codex/skills/goal-mode/SKILL.md` and
  `profiles/claude/skills/ultracode-orchestration/SKILL.md`.
- Korean: **[코덱스와 클로드](../ko/코덱스와클로드.md)**
