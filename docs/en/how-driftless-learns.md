# How Driftless learns (and what it has learned so far)

Most "AI" projects hide their mistakes. Driftless does the opposite: the
trial-and-error *is* the product. This page explains, in plain language, how this
repo turns its own mistakes into rules that cannot be re-broken, and gives an
honest list of real lessons it learned while building itself.

If you only read one sentence: **every recurring mistake gets promoted to a
surface that is harder to ignore, and the five cost axes are supposed to trend
down over time.** That is the whole loop.

---

## 1. Trial-and-error is the feature, not the embarrassment

A self-improving maintainer that never made a mistake would be lying to you. The
honest version makes mistakes, *notices* them, and then makes the same mistake
mechanically impossible the next time. The value is not "it is perfect" — it is
"it gets harder to break the longer it runs."

So Driftless does not delete its scars. It records them, and it records the
**enforced fix** each one earned. The list further down is real, not a brochure.

---

## 2. The learning loop: a mistake climbs a ladder

When the maintainer learns a lesson, the lesson does **not** just sit in a memory
note. Memory is recall-based — it is not loaded in full every session, so a lesson
kept only in memory will, sooner or later, be forgotten at the exact moment it
mattered, and the mistake happens again.

Instead, the lesson is **promoted** to a stronger surface, chosen by one question:
**what breaks if this is ignored?** The bigger the breakage, the higher it climbs.

```
memory note  <  on-demand skill  <  hot rule  <  hook  <  gate script
  (weakest:                                            (strongest:
   recall only)   (trigger)  (every session)  (auto-run)   blocks the merge)
```

- **Memory** — a notes file. Background you only need once; mild, recoverable
  friction if forgotten. **Never the only home for a high-stakes lesson.**
- **On-demand skill** — a procedure that fires on trigger words (how to close a
  ticket, how to resolve PR feedback). Ships to users, so no machine-specific path.
- **Hot rule** — a short line in the always-loaded instruction file
  (`CLAUDE.md` / `AGENTS.md`). Must hold *every* session.
- **Hook** — the harness runs it automatically (inject, block, sync, clean up), so
  no human has to remember.
- **Gate** — a check wired into the pull-request review that **mechanically fails**
  the work until the lesson is honored. The top rung.

A lesson whose recurrence would cause something **irreversible, a security leak,
or a false "done"** is pushed all the way to a hot rule or a gate — never left in
memory alone. The full routing rule (damage on repeat, dependence on a human
remembering, scope, product-vs-internal, tool-shared-vs-specific) is in
**[The Lesson-Promotion Ladder](./lesson-promotion-ladder.md)**, and one mistake
is walked all the way up the ladder in
**[evidence/lesson-ladder/](../../evidence/lesson-ladder/example-lesson.md)**.

### Why the top rung is trustworthy: the negative fixture

A gate that has only ever seen *good* input proves nothing — it could be a no-op.
So each gate ships a **negative fixture**: a small, deliberately-broken input that
re-introduces the exact banned mistake, and the gate is *required to FAIL* on it.
If a future change quietly removes the protection, the fixture stops failing, and
that turns into a red build. The guard cannot rot silently. (Containment is proven
by feeding it a forbidden-path fixture; Windows text-safety by a non-ASCII fixture
that must be rejected. We prove the FAIL direction, not just the PASS.)

---

## 3. The five axes are supposed to trend down

Driftless does not optimize for "more output." It pushes five measurable axes
the right direction over time — descending a gradient toward the cheapest, calmest
way to get correct work merged:

| Axis | What it means | Direction |
|---|---|---|
| **Tokens** | How much the AI reads/writes per task | down |
| **Manager intervention** | How often it has to ask you | down |
| **Time** | How long a task takes | down |
| **Money** | Usage cost (for subscription plans this is requests/sessions, not dollars) | down |
| **Performance** | Whether the work is actually correct (gates pass) | up |

A change is only an improvement if no axis regresses past its watch trigger while
the target axis improves — that is a gradient, not a single-axis win. Each session
is meant to leave telemetry so the trend is *visible, not guessed*. How a
before/after delta is captured (and which numbers are still honestly UNVERIFIED)
lives in **[evidence/5-axis-roi/](../../evidence/5-axis-roi/README.md)**.

One concrete token-axis rule worth calling out: **keep the session-hot context
prefix byte-stable**. Prompt-caching makes a repeated, unchanged prefix ~10x
cheaper to re-read than to re-create, so volatile content (timestamps,
run-scratch, big evidence dumps) goes at the tail or into artifacts — never edited
into the front of the always-loaded rules mid-session. Editing the front silently
invalidates the cache and re-pays for the whole prefix every turn.

> **Honest status (v0.1.0, day one):** the *method* and the validation harness are
> implemented and run today. The per-axis production numbers across many merged
> PRs are still being captured and are labeled **UNVERIFIED** until a dated run
> publishes both sides of a pair. We do not promote a hoped-for number to a
> headline.

---

## 3b. Two tools, two failure modes (model-specific learning)

The ladder above handles **shared** lessons. But Claude and Codex do not make the
*same* mistakes — they fail differently — so Driftless splits the learning:

- **Shared lessons go to the shared tier, once.** A rule both tools need (e.g.
  "a static change is UNVERIFIED until a gate proves it") lives in
  `profiles/shared/` and the mirror-parity gate keeps both profiles in sync — one
  edit fixes both.
- **Tool-specific mistakes are tracked and fixed per profile.** A quirk that only
  one tool exhibits (a Claude-only phrasing trap, a Codex-only goal-loop habit) is
  captured and corrected **only in that profile's tier**, never forced onto the
  other. A model-specific mistake optimizer means each tool's recurring failures
  are driven down on their own track, so one tool's workaround can't distort the
  other tool's behavior.

This is the point of the two-profile design: improve together where the lesson is
universal, improve separately where the failure is tool-shaped. Neither tool is
held back by the other's quirks.

---

## 4. What this project actually learned (an honest changelog)

These are real recurring mistakes from building Driftless and the runtime it grew
from. Each one earned an enforced fix — this is the ladder in action, not theory.

### "A buried tool error read as false completion" -> now a discipline
In a long session the agent fired a batch of tool calls; one failed (an edit that
did not match, or a parallel command that errored), the failure scrolled past, a
later unrelated step reported PASS, and the green PASS got read as "the whole batch
worked." The agent called the ticket **Done** while a change had silently never
landed — and a single errored call in a big parallel batch could even **cancel its
healthy siblings**, losing good work too.
**Fix (climbed to a hot rule):** keep parallel batches small; run any mutation or
dependent-argument call **sequentially**; an empty or malformed tool result is
**UNVERIFIED, never PASS** — retry once, then stop, never run a blind irreversible
action on unseen output. Errored changes are re-confirmed individually before any
"Done." (Walked fully up the ladder in
[evidence/lesson-ladder/](../../evidence/lesson-ladder/example-lesson.md).)

### "Template edits aren't live until materialized" -> verify the built artifact
A profile is built from templates into a runtime home. Editing the *template* and
then testing felt like it should work — but the running agent reads the
**materialized** copy, not the template, so an "applied" change was not actually
live yet. Reading the template back looked like confirmation and was not.
**Fix:** behavior claims require evidence from the *built/running* path, not the
source template; a static read of the template leaves behavior UNVERIFIED. After
editing a launcher, verify it with a real low-side-effect run, not by re-reading
the text.

### "An optimization quietly dropped a safety line" -> now a gate with a negative fixture
A skill was "optimized" to save tokens and, in doing so, silently deleted a safety
line. Saving tokens is good; deleting a guardrail to do it is a regression.
**Fix (climbed to a gate):** a static validation harness scores every candidate
skill edit and **rejects** any that drops a protected term or adds a forbidden
boundary phrase — proven by a built-in negative fixture that deliberately removes
the safety line and asserts the verdict must be REJECT. Re-introducing the bad
change can no longer reach the main branch.

### "Resetting the profile wiped the memory" -> preserve what must survive a reset
A launcher "reset profile" flag rebuilt the isolated home by deleting it whole —
which also deleted the (gitignored) memory notes that were supposed to persist
across sessions. Measured, real, and exactly the kind of irreversible mistake the
ladder targets.
**Fix:** the reset path now preserves the durable state directory, verified, and
the canonical fact was also written into committed docs so a memory wipe cannot
erase the lesson about memory wipes.

### "New scripts broke a different gate via line endings" -> normalize and keep scripts ASCII
A newly added script with the wrong line endings produced a stray version-control
warning, and that warning leaked into another gate's output and parsed as a
*spurious* failure. Unrelated tooling, real red build.
**Fix:** scripts are kept ASCII with no byte-order-mark and the expected line
endings; the local gates are run end-to-end before pushing so a formatting quirk
is caught locally instead of by a confusing downstream failure.

### "Partial port reported as a full port" -> completeness must be proven, not claimed
When porting a set of tools, "ported them" sometimes meant "ported most of them."
A partial job reported as complete is a quiet false "done."
**Fix:** a port enumerates the full set up front, reports the count, names every
deliberate exclusion with a reason, and proves the remaining-unported count is zero
before "Done" — with the completeness check structural, not a promise in prose.

### "Rejected a heavy idea without testing it" -> lean means pilot small, not discard
A useful external idea looked expensive, so it was closed "too heavy, lean
violation" — without ever trying it. That is the opposite of lean. Lean is not
"reject anything big"; it is **start small**: take the core, build the *smallest*
pilot that fits the real flow, measure it on the five axes, then adopt a minimal
adapted form if it earns its place. A knowledge-graph becomes a one-page
repo-structure summary file; a unified-state database becomes a small read-only
index over the issues/PRs/evidence that already exist.
**Fix:** "heavy" is no longer a valid rejection reason in the adoption and
root-goal-check skills. A heavy candidate must first be reduced to its smallest
pilot and measured; only a measured no-gain result (or real upkeep cost) closes it
out. Skipping the pilot to wave a big idea away is recorded as the deferral mistake
it is.

### "A smoke pass got mistaken for route readiness" -> now promotion needs a matrix
A small live smoke can prove that an integration is reachable, but it does not
prove the route is useful across real work. A candidate can pass one tiny prompt
and still return empty content, generic templates, or unsupported metrics when it
is asked to do planning, review, escalation, or manager-facing explanation.
**Fix:** route promotion requires a diversified real-use matrix, not a single
smoke. The matrix records success rate, quality, latency, token use, estimated
cost, manager intervention, and safety penalties. Unsupported operational
numbers are penalized, and a route that cannot sustain the matrix stays
supervised or disabled even if the smoke passed.

### "Fallback order got mistaken for provenance" -> record the winning route
A fallback list only says what the system planned to try. It does not prove which
provider, model, endpoint, or credential route actually produced a bad chunk or
useful answer. Without that per-call trace, later root-cause analysis turns into
guesswork.
**Fix:** every generated chunk or worker call that may be cached, scored, or
used for routing must record the selected provider, selected model, route key,
attempt status, latency, cost estimate, and error/success code. The log may
record credential *names* or route aliases, but never secret values.

### "A worker answer was treated as done before the parent judged it" -> close the loop
A worker can return a technically valid answer and still be useless after the
parent agent checks it against the real task. If the run is not closed with the
parent decision, cost, time, quality, and manager-intervention count, the next
route decision is based on hope instead of observed usefulness.
**Fix:** every worker call used for routing or future reuse must end with a
parent closeout record. The closeout records whether the answer was accepted,
retried, escalated, or rejected, then feeds the gradient report that decides
whether future runs should keep, demote, escalate, or gather more evidence.

### "Drove the loop on a clock instead of on finish" -> trigger the next cycle when work ENDS
The autonomous loop was re-entered by a fixed timer (every few minutes / couple of
hours). That fires uselessly while idle (wasted tokens) and is *not* "start the
next task immediately" when a task runs longer than the interval. The honest
trigger is the moment work finishes, not a wall clock.
**Fix:** the next cycle is triggered on **finish** — Claude via a `Stop` hook that
re-enters with the next gap as its instruction, Codex via the runner's finish hook —
guarded by a small iteration counter so it stops when the backlog is genuinely
converged. A timer is only a backup for a fully-closed session. The same
finish-hook also drives the periodic drift/optimism audit, so the audit isn't a
separate clock either. (Tool-shaped differently, same principle — see
[Codex and Claude](./codex-and-claude.md).)

> Two reach/process lessons we hold privately (manager-facing strategy lives
> outside this public repo): things like *"inline links on some platforms get
> near-zero reach, so the link goes in the reply, not the post"* are the same
> shape — observe, write the rule down where it is enforced, stop repeating it.
> The mechanism is identical; only the topic differs.

---

## 5. The takeaways (the rules behind the rules)

- **Where a lesson lives is decided by blast radius, not convenience.**
  Irreversible / security / false-"done" risks may **not** rest in memory alone.
- **Climb until the cost is contained.** Annoying-but-recoverable can stay a skill
  or a note; costly-on-repeat has to reach a hook or a gate.
- **Prove the guard with a negative fixture.** A gate that has never failed is not
  evidence; a gate that *still fails* on the re-introduced mistake is.
- **Implement the surface in the same session** the lesson is learned — do not
  defer it back into a memory note and walk away.
- **Trend the five axes, do not chase one number.** A win that regresses another
  axis past its watch trigger is not a win.

That is "Driftless" doing what its name promises: it does not slowly wander off
the rules it already learned, because every rule that matters is parked on a
surface that is actually enforced.

---

## Where to go next

- **[The Lesson-Promotion Ladder](./lesson-promotion-ladder.md)** — the full rule
  for choosing a surface.
- **[evidence/lesson-ladder/](../../evidence/lesson-ladder/example-lesson.md)** —
  one mistake walked all the way up the ladder, ending in a gate.
- **[evidence/5-axis-roi/](../../evidence/5-axis-roi/README.md)** — how a measured
  before/after delta is captured per axis.
- **[evidence/](../../evidence/README.md)** — what a fresh-clone reviewer can
  inspect instead of taking on faith.
- Korean: **[드리프트리스는 어떻게 학습하나](../ko/드리프트리스는어떻게학습하나.md)**
