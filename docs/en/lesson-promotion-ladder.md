# The Lesson-Promotion Ladder

How Driftless decides **where** to put a lesson so that a recurring mistake stops
recurring - instead of piling up in a memory file that is only sometimes read.

This is the "driftless" half of the promise: the agent does not slowly wander off
the rules it already learned, because every rule that matters is parked on a
surface that is actually enforced.

## The core idea: "what breaks if it is ignored" decides the surface

Agent memory is **recall-based**. It is not loaded in full at the start of every
session - only fragments surface when something reminds the agent of them. So a
lesson kept **only** in memory will, sooner or later, be forgotten at the exact
moment it mattered, and the same mistake happens again.

The fix is a ladder. The more damage a repeat would cause, the higher up the
ladder the lesson must live - and the higher rungs are **enforced** (loaded every
session, or run automatically, or blocking a merge) rather than merely
remembered.

## The ladder (bottom = softly enforced, top = hard enforced)

| Rung | How it is enforced | Put a lesson here when... | Example |
| --- | --- | --- | --- |
| **Memory** (a notes file) | Recall-based; not read every time | It is background/context you only need to know once. Forgetting it causes mild, recoverable friction. **Never park a lesson here alone if a repeat would be irreversible, a security issue, or a false "done".** | A host quirk, how a tool behaves, the background of a past decision. |
| **Skill** (an on-demand `SKILL.md`) | Activated by trigger words | A procedure needed only for a specific class of task, with clear triggers. **Ships to product users, so no machine- or repo-specific path may be baked in.** | How to open a ticket, how to resolve PR feedback, a debugging routine. |
| **Hot rule** (the always-loaded `CLAUDE.md` / `AGENTS.md`) | Loaded into context every session | A short rule that must hold **every** session. Must be small and justified (hot context is a budget). | Evidence honesty, the containment boundary, "no peer/recursive AI by default". |
| **Hook** (a harness hook, e.g. pre-tool / stop) | The harness runs it automatically | An **automatic** behavior a human would forget to do by hand (inject, block, sync, clean up). Verify it with a real launch - a bad hook path can freeze the desktop agent. | Sync local skills, block an unsafe action, clean up a one-shot file. |
| **Gate** (a `Test-*.ps1` script wired into the PR check) | Runs on every PR; FAIL blocks the merge | A rule humans keep breaking even after it was written down. Prose did not hold. Prove the FAIL direction with a **negative fixture**. | Block a self-weakening edit, enforce Windows text safety, detect a deleted rule. |

## How to decide which rung (the routing rule)

Ask these in order:

1. **Damage on repeat.** If ignoring it leads to something irreversible
   (commit / push / merge / delete), a security leak, or a false "done", it goes
   to a **hot rule or a gate** - never memory alone. If it is annoying but fully
   recoverable, a skill or memory is fine.
2. **Dependence on a human remembering.** If it only works when a person
   remembers to do it, and it has already been broken **more than once**, automate
   it as a **hook or a gate**. (Trying to hold it with prose or memory and failing
   is the signal to make it structural.)
3. **Scope.** Needed every session -> hot rule. Only for a specific task class ->
   skill. An automatic behavior -> hook. A one-time background fact -> memory.
4. **Product vs. project-internal.** Does the rule also help a downstream product
   user? Then it lives on a product surface (a shipped skill, the product's
   `CLAUDE.md`). Is it specific to developing *this* repo (a path on this machine,
   a link someone handed you, an internal lookup)? Then it lives **only** in the
   repo-root instruction file and never ships - a product user has none of that
   context, so baking it into a shipped skill is itself a recurring mistake.
5. **Tool-shared vs. tool-specific.** Same rule regardless of which agent tool
   runs it? It belongs to the **shared** tier (one edit, both profiles - this is
   the mirror that keeps the two tool profiles driftless). Specific to one tool?
   It lives in that tool's tier.
6. **Propagation reach.** Must the rule hold in **every project on the machine**,
   not just the repo where it was learned? Then a repo's always-loaded
   instruction file is the *wrong* home - a global-worthy rule written only into
   one repo's `CLAUDE.md`/`AGENTS.md` is structurally **trapped folder-local**
   and never reaches the other projects. It must live on a surface your global
   connector actually propagates: a **universal rules file** imported by the
   global instruction file, a **universal hook** declared in a single manifest,
   or a **plugin skill** loaded through a junction/symlink. Editing those
   in-repo *is* the global update (the link layer reflects it live), so it needs
   no risky direct edit of the global config home - which should stay a **thin
   link layer** with no content of its own. Watch the always-on surfaces' size
   budget: if a prose rule does not fit, deliver it through the always-on hook
   channel instead. The misrouting trap to avoid: confusing propagation *reach*
   (how far the rule must apply) with *mutation target* (which file you edit) -
   "this must apply globally" almost never means "edit the global home by hand".

## The reverse direction: a cross-project learning inbox

Routing rule 6 covers rules flowing *out* to every project. The opposite flow
needs a channel too: a session working in some *other* project learns a
reusable, project-agnostic lesson - and with no channel, that lesson dies in
that project's local memory and the runtime kit never improves. The proven
smallest form (private companion deployment, June 2026): ship a tiny
**append-only inbox helper** beside the globally-linked profile (so every
project's session can reach it through the same link layer), have it append one
JSON line per lesson into the runtime repo's ignored scratch area, remind every
session of the channel via an always-on universal rule, and have the runtime
repo's learning loop **triage** the inbox on its next session - classify each
entry by tier and reach, promote it up this ladder, and record skipped entries
with a reason. Capture must be one command; triage must be owned by the runtime
repo, not the capturing session.

## Memory must never be the *only* home for a high-stakes lesson

This is the heart of the rule. A lesson whose repeat would be irreversible, a
security issue, a false "done", or a known repeat mistake **fails if it lives in
memory alone** - because if recall misses it, it gets broken again. Such a lesson
**must also be promoted to an enforced surface** (hot rule / hook / gate), and
memory becomes only the pointer and background, not the first line of defense.

And: once you decide the rung, you **implement that surface in the same work
session**. Investigating, writing a memory note, and stopping is the failure this
ladder exists to prevent. If you genuinely cannot finish the surface now, open
the smallest follow-up task and report its id.

## Worked example: a mistake climbing to an enforced gate

A concrete climb, the kind this ladder is built for:

1. **Memory.** An agent once shipped an "optimized" skill that quietly deleted a
   safety line to save tokens. A note is added: *"do not drop safety lines when
   shrinking a skill."* Useful - but recall-based, so it can be missed.
2. **Hot rule.** It happens a second time. The cost is now clearly a safety
   regression, so a one-line rule goes into the always-loaded instructions:
   *"an optimization may never drop a protected safety line or boundary."* Loaded
   every session - stronger, but still depends on the agent honoring prose.
3. **Gate with a negative fixture.** It is a *repeat* mistake whose damage is a
   safety regression, so prose is not enough - it becomes structural. A static
   gate (`scripts/Test-SkillOptValidationHarness.ps1`) scores every candidate edit
   and **rejects** any candidate that drops a protected term or adds a forbidden
   boundary phrase. Crucially, the gate ships with a **negative fixture** - the
   built-in `drops-safety` pair - which deliberately deletes the safety line and
   adds a host-global allowance and asserts the verdict must be REJECT. If a future
   refactor ever weakened the gate so that the bad change slipped through, the
   negative fixture's expectation would no longer be met and the gate itself would
   FAIL the PR.

That negative fixture is the proof that the mistake is now **blocked, not just
remembered**: re-introducing the bad change can no longer reach `main`. That is
the top of the ladder, and the difference between "we wrote it down" and "it
cannot happen again".

## Why this document exists

Lessons kept accumulating in memory and never climbed to an enforced surface, so
the same mistakes recurred. The root cause was that "where does this lesson go?"
had no single, explicit rule and **memory had become the default destination**.
This ladder changes that default: when a repeat would be costly, the first
destination is an enforced surface, and memory is only the backup pointer.
