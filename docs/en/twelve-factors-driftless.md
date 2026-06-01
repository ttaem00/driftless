# The 12-Factor Agent principles, read through Driftless

[12-Factor Agents](https://github.com/humanlayer/12-factor-agents) by HumanLayer
is a well-regarded checklist for building LLM agents that survive contact with
production. It is a *design* reference, not a library: it tells you which
properties a reliable agent should have, and lets each project earn them in its
own way.

This page is the honest version of "we read the reference and adopted it." It
does **not** copy 12-factor's structure or code. Instead it asks, factor by
factor: *does Driftless already embody this, and how — or is this somewhere we
should still improve?* Where the answer is "we already do this," it points at the
concrete machinery. Where the answer is "partially," it says so plainly and
names the gap. No factor is marked green just to look complete.

> One-line summary: **Driftless strongly embodies the factors about owning your
> prompts and context, small focused agents, and contacting humans as a gated
> tool. It partially embodies the factors about explicit control flow, unified
> state, and pause/resume — those lean on the harness more than on our own code,
> and we say so.**

A quick map of where the "owning your prompts/context", "small focused agents",
"contact humans", "unify state", and "compact errors" ideas land:

| 12-factor principle | Driftless verdict | Where it lives |
|---|---|---|
| 2. Own your prompts | **Embodies well** | Single-source `profiles/shared/` + mirror-parity gate |
| 3. Own your context window | **Embodies well** | Lean hot rules, token-runaway guard, evidence artifacts |
| 7. Contact humans with tool calls | **Embodies well** | Four manager-only escalation gates, plain-language report |
| 10. Small, focused agents | **Embodies well** | Lean skills, narrow overnight workers under a parent |
| 9. Compact errors into context | **Partial** | Compact UNVERIFIED status + retry-once rule; not a structured error-summary loop |
| 5. Unify execution & business state | **Partial** | Decision register + issue/PR body as state; not one machine-checked store |
| 8. Own your control flow | **Partial** | Gates + ladder constrain flow; step orchestration is the harness's |
| 6. Launch / pause / resume | **Partial** | Resume via launcher wrapper; no first-class checkpoint API |
| 12. Stateless reducer | **Partial (by analogy)** | Each session re-reads intent from durable state; not a literal pure reducer |
| 1 / 4. NL→tools / tools as structured output | **Inherited** | Provided by Claude Code / Codex harness, not re-implemented |
| 11. Trigger from anywhere | **Out of scope (on purpose)** | One front door (the launcher) is a containment choice, not a miss |

The rest of this page walks each factor with evidence and the honest gap.

---

## Factors Driftless embodies well

### Factor 2 — Own your prompts

> *12-factor:* treat prompts as first-class code you control, not framework
> defaults you inherit.

This is close to the center of what Driftless **is**. The agent's behavior is not
a vendor's hidden default — it is a small set of owned, version-controlled,
reviewable instruction files. The always-loaded hot rules live in `CLAUDE.md`
(Claude) and `AGENTS.md` (Codex), and the shared half — the safety contract, the
evidence vocabulary, the tool-agnostic skills — lives **once** in
`profiles/shared/`. Both tools read the same source, and a **mirror-parity gate**
fails the build if the two profiles drift apart.

Driftless actually goes one step past "own your prompts": it *owns the rule for
how prompts change*. Instructions are deliberately kept lean (long procedures go
to skills and scripts, not into the always-on context), and a `instruction-edit`
checklist forces every edit to choose hot-vs-on-demand placement and record the
rejected alternative. Owning the prompt includes owning its diet.

**Verdict: embodies well.** The prompt is code, it is single-source, and a gate
keeps the two copies honest. Related: [Single-source two-profile
mirror](./single-source-mirror.md).

### Factor 3 — Own your context window

> *12-factor:* actively decide what reaches the model; do not let context
> passively accumulate.

Driftless treats context as a budget to be spent down, not a bucket to fill. Two
mechanisms make this concrete:

- **Lean hot context.** Only always-needed rules sit in the session-hot file;
  everything conditional is pushed to on-demand skills, `docs/`, and scripts. The
  five-axis gradient (see [How Driftless learns](./how-driftless-learns.md))
  literally counts **tokens** as an axis to push *down*, so "read less per task"
  is a measured goal, not a vibe.
- **A token-runaway guard.** Any large raw output — long logs, big JSON dumps,
  wide search results — is written to an evidence artifact, and only a short
  summary plus the artifact path returns into the live context. The full text
  never floods the window.

This is exactly the 12-factor instinct ("curate what the model sees") expressed
as a containment-and-cost rule rather than a manual prompt edit.

**Verdict: embodies well.** Context is curated by policy and by a runaway guard,
and one of the five tracked axes is the size of what the model reads.

### Factor 7 — Contact humans with tool calls

> *12-factor:* asking a human for help should be a normal, structured action the
> agent can take — not a crash, and not a thing it routes around.

Driftless's whole manager relationship is built on this idea, sharpened into a
**small, fixed set of escalation gates**. The agent is autonomous *inside* a
fence and must hand specific decisions back to the human:
product/priority calls, credentials, billing/quota, public release,
anything destructive or irreversible, host-global promotion, user-data transfer,
force-push, and history reset. Those are the *only* things it asks about — so
"contact the human" is a precise tool, not a nervous habit.

And the contact itself is designed for a non-developer: the morning report is in
plain language and starts with one of four labels — **done / needs your decision
/ blocked / in progress** — with raw commands and links placed *after* the
summary as evidence, never instead of it. The escalation is a clean, typed
"return value to the human," which is the spirit of the factor.

**Verdict: embodies well.** Human contact is a defined, minimal, typed
escalation, not an exception path. Related: [Guardrails](./guardrails.md).

### Factor 10 — Small, focused agents

> *12-factor:* prefer narrow agents with a clear job over one monolith.

Driftless is composed, not monolithic. Two layers show it:

- **Skills are small and single-purpose.** Closing a ticket, resolving PR
  feedback, running the containment check, briefing the manager — each is its own
  on-demand skill with a narrow trigger, rather than one giant do-everything
  prompt.
- **Overnight work fans out into narrow workers under a parent.** The parent
  session surveys the backlog and delegates conflict-light slices to focused
  worker sessions (bounded concurrency, each with one job), instead of one agent
  trying to hold the entire repository in its head.

Keeping each unit small is also why "own your context" above is even possible —
a focused agent has a smaller window to curate.

**Verdict: embodies well.** Both the skill layer and the overnight orchestration
favor many small, focused units over a monolith.

---

## Factors Driftless embodies partially (the honest gaps)

### Factor 9 — Compact errors into the context window

> *12-factor:* when something fails, feed a *compact* summary back to the model so
> it can recover without burning tokens re-reading the whole failure.

Driftless has the **compaction instinct** but not the full structured
error-recovery loop.

- *What it already does:* a failed or empty tool result is treated as a compact,
  typed status — **UNVERIFIED, never PASS** — with a tight rule: retry the same
  call once, and if it is still empty, say "transmission loss UNVERIFIED" and
  **stop**, rather than dumping the raw failure or acting blind on it. The
  five-axis tokens-down pressure and the runaway guard also keep error output from
  ballooning. So errors *are* compacted, and the agent does *not* spend tokens
  re-reading them.
- *The gap:* this is a "compact and halt safely" discipline, not 12-factor's
  "compact the error and let the agent iterate toward a fix in-loop." Driftless
  deliberately prefers *stop and re-confirm* over *auto-retry the reasoning* on a
  hard failure, because a blind retry near an irreversible action is the more
  expensive mistake for a non-developer's repo. That is a defensible trade, but it
  means we do **not** yet have a structured error-summary-and-self-heal loop.

**Verdict: partial.** Errors are compacted and never silently swallowed, but the
posture is safe-halt, not iterate-in-context. A future improvement: a small,
bounded structured-error summary that an overnight worker can use to retry a
*reversible* step automatically while still hard-stopping on irreversible ones.

### Factor 5 — Unify execution state and business state

> *12-factor:* don't keep a separate hidden "agent state" that can disagree with
> your real data model; keep them unified.

Driftless's "business state" is its GitHub issues, PRs, and a dated decision
register; its "execution state" is what a session is doing right now.

- *What it already does:* durable state lives in the **issue/PR body** under a
  dated section and in `docs/MANAGER_DECISIONS.md`, *not* in ephemeral chat. Every
  session re-reads that register before working, so the agent's working memory is
  re-derived from the same record a human reads. There is no separate secret
  scratch-state that the manager can't see — the audit trail *is* the state.
- *The gap:* the two are unified by **convention and re-reading**, not by a single
  machine-checked store with a schema. An overnight done-state gate checks that no
  unfinished lane is hidden behind a "done" claim, which enforces *part* of this —
  but execution progress and business records are still two surfaces kept in sync
  by discipline plus that gate, not one unified object.

**Verdict: partial.** State is durable, human-visible, and re-read each session
(strong), but it is reconciled by gate + convention rather than being one unified
store (the literal factor).

### Factor 8 — Own your control flow

> *12-factor:* write explicit logic for the agent's loop instead of letting the
> model improvise every branch.

- *What it already does:* Driftless does **not** let the model decide the
  high-stakes branches freely. The escalation gates (Factor 7), the
  lesson-promotion ladder, and the containment / text-safety / mirror-parity gate
  scripts are explicit, deterministic control flow that the model cannot talk its
  way around: a forbidden path *fails*, a non-ASCII script *fails*, a "done" with
  hidden lanes *fails*. That is owned control flow at the decision points that
  matter.
- *The gap:* the *step-to-step* orchestration — which tool to call next inside a
  task — still lives largely in the model's reasoning plus the host harness
  (Claude Code / Codex), not in Driftless-owned loop code. We own the **guardrails
  on** the control flow more than we own the control-flow engine itself.

**Verdict: partial.** The dangerous branches are explicitly gated and owned; the
fine-grained loop is the harness's and the model's. This is an intentional
division of labor (don't re-build the harness), but it is not full ownership.

### Factor 6 — Launch / pause / resume with simple APIs

> *12-factor:* an agent should stop and resume cleanly without losing progress.

- *What it already does:* a session resumes through the **launcher wrapper**, not
  a bare resume command (a lesson learned the hard way — a bare resume could
  corrupt the terminal UI). Durable progress survives a stop because it lives in
  issues/PRs and the decision register (see Factor 5), so a fresh session can pick
  up the thread by re-reading.
- *The gap:* "resume" is *re-read the durable record and continue*, not a
  first-class checkpoint/restore API with a saved execution-state token. There is
  no `pause()` that serializes the in-flight step and a `resume()` that restores
  it byte-for-byte; recovery is reconstruction, not snapshot-restore.

**Verdict: partial.** Resume is safe and works via durable state + the wrapper,
but it is reconstruction-based, not a literal pause/resume API.

### Factor 12 — Make your agent a stateless reducer

> *12-factor:* model the agent as a pure function from input state to output
> state, so behavior is reproducible.

This is the factor Driftless matches most by *analogy* rather than by
construction.

- *What it already does:* an overnight session is treated as close to stateless —
  it re-derives what to do from durable inputs (issues, PRs, the decision
  register, the goal) each time rather than trusting hidden in-memory carryover,
  and it records decisions back out to that same durable record. Re-reading intent
  every session instead of trusting accumulated context is very much the
  stateless-reducer spirit, and it is *why* "Driftless" can promise the agent
  won't wander.
- *The gap:* a real reducer is deterministic — same input, same output. An LLM
  session is not pure (sampling, model updates, tool latency), and Driftless does
  not pretend otherwise. We get the *discipline* of a reducer (no trusted hidden
  state) without the *guarantee* (determinism).

**Verdict: partial, by analogy.** The "re-read durable state, don't trust hidden
carryover" discipline is real and load-bearing; literal pure-function determinism
is not claimed.

---

## Factors that are inherited or intentionally out of scope

### Factors 1 & 4 — Natural language to tool calls / tools are just structured output

These two are about the *mechanics* of turning model output into typed tool
calls. Driftless does not re-implement them — they are provided by the host
harness (Claude Code and Codex both expose structured tool-calling). Driftless
sits one layer up and spends its effort on *which* tools are allowed, *what*
counts as evidence, and *when* a human is contacted. So these factors are
**inherited, not re-built** — correctly, since re-implementing the harness would
violate "don't rebuild the engine."

### Factor 11 — Trigger from anywhere, meet users where they are

12-factor encourages many entry points (Slack, email, webhooks). Driftless
deliberately has **one front door**: the launcher that pins the isolated config
home. This is not an oversight — multiple ambient triggers are in direct tension
with **containment** (a single, audited entry point is easier to keep inside the
fence) and with the non-developer manager model (one paste-before-bed prompt, one
morning report). So this factor is **intentionally out of scope**, and we name it
rather than pretend we cover it.

---

## The honest scoreboard

- **Owns its prompts, owns its context, stays small, contacts humans cleanly** —
  these are core Driftless strengths and are backed by gates and a measured token
  axis, not just intentions. (Factors 2, 3, 7, 10.)
- **Compact errors, unified state, owned control flow, pause/resume, stateless
  reducer** — Driftless has the *instinct* and partial machinery for each, with a
  named, honest gap. The recurring theme of the gaps: Driftless owns the
  **guardrails and the durable record** but leans on the host harness for the
  **execution engine**, and it prefers **safe-halt** over **auto-iterate** near
  irreversible actions. (Factors 5, 6, 8, 9, 12.)
- **NL→tools / structured tools** are inherited from the harness; **trigger from
  anywhere** is intentionally declined for containment. (Factors 1, 4, 11.)

The single most useful concrete improvement this review surfaces: **Factor 9** —
a small, bounded *structured-error summary* that lets an overnight worker
auto-retry a clearly **reversible** step from a compact failure, while still
hard-stopping on anything irreversible. That would close the one gap where
12-factor's "compact errors and iterate" and Driftless's "compact errors and
halt" most clearly diverge, without giving up the safety posture.

---

## Where to go next

- **[How Driftless learns](./how-driftless-learns.md)** — the lesson-promotion
  ladder and the five axes (the engine behind "own your prompts/context").
- **[Single-source two-profile mirror](./single-source-mirror.md)** — why one
  prompt edit improves both tools.
- **[Guardrails](./guardrails.md)** — the escalation gates behind Factor 7.
- **[Adopt an external tool safely](./adopt-external-tools-safely.md)** — the
  same "read the reference, adopt honestly" discipline applied to any repo.
- Korean: **[12요소로 본 드리프트리스](../ko/12요소.md)**
