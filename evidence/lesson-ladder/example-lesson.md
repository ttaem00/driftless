# Lesson ladder — one lesson, fully climbed

Driftless turns recurring mistakes into **enforced surfaces** instead of letting
them pile up as notes nobody reloads. The rule that decides *where* a lesson goes
is simple: **what breaks if it is ignored?** The bigger the breakage, the higher
it climbs.

```
memory  <  on-demand skill  <  hot rule  <  hook  <  gate
weakly enforced  ------------------------------------>  strongly enforced
(recall only)        (trigger)   (every session)  (auto-run)   (blocks the merge)
```

Memory is recall-based — it is not loaded every session. So a lesson whose
**recurrence costs an irreversible, security, or false-Done misjudgment** must
not live in memory alone. It has to be promoted to a surface that is *forced* to
load or run. This file walks one real recurring mistake all the way up.

---

## The lesson: "a buried tool error read as false completion"

**The recurring mistake.** In a long session the agent emits a batch of edits and
tool calls. One of them fails — say an `Edit` that did not match, or a parallel
`Bash` call that errored. The failure scrolls past, an unrelated later step
reports PASS, and the agent reads the green PASS as "the whole batch worked." It
declares the ticket **Done** while a change silently never landed. Worse, a
single errored call in a large parallel batch can **cancel its healthy siblings**
("Cancelled: parallel tool call ... errored"), so good work is lost too.

This is exactly the class the ladder exists for: the cost of recurrence is a
**false-Done misjudgment** and possible lost work — not a mere inconvenience. So
memory alone is forbidden as the resting place.

### Rung 1 — memory (where it started, and why that is not enough)

First it was just a memory note: *"a buried tool error can look like
completion — re-check errored changes individually."* True, useful, and
invisible the next session, because memory is recalled, not guaranteed-loaded.
The mistake recurred. Memory stays as the **pointer/background**, never as the
only defense.

### Rung 2 — on-demand skill

Promoted into a finish-to-done / verification skill: when the agent is closing a
ticket, the skill's procedure says *re-confirm each errored change individually
before claiming Done; never let a later PASS absorb an earlier ERROR.* Better —
but it only fires when the relevant trigger is hit, so a closeout that skips the
trigger still slips through.

### Rung 3 — hot rule

Because this must hold **every session, not just when a skill triggers**, the
core rule is written into the always-loaded instruction file (the repo's hot
rules): keep parallel `Bash` batches small; run any mutation or
dependent-argument call **sequentially**; a tool result that comes back empty or
malformed is **UNVERIFIED, never PASS** — retry once, then stop, never run a
blind irreversible action on unseen output. Every session loads this. But a rule
is still prose the agent must *choose* to follow.

### Rung 4 — hook

Some of it can be taken out of human/agent judgment entirely and handed to the
harness. A `PreToolUse` / `Stop` hook can refuse to let a session **stop** (claim
done) while an un-reconciled tool error sits in the transcript, or can cap a
parallel batch automatically. The harness runs it; the agent cannot forget it.

### Rung 5 — gate (the top rung: it blocks the merge)

The strongest surface is a **gate script** wired into the PR check. For this
lesson the gate refuses to let a closeout/merge proceed while an errored change
is unreconciled, and it is proven with a **negative fixture**: a small,
deliberately-broken input that re-introduces the exact mistake. The gate must
**FAIL** on that fixture. If a future refactor quietly removes the protection,
the negative fixture stops failing — and *that* is caught, because the gate also
asserts the fixture still fails.

```
# concept (PowerShell pseudocode)
$bad = Read fixture: "transcript with an errored Edit followed by an unrelated PASS,
                      then a Done claim"
$result = Invoke-FalseCompletionGate $bad
if ($result -ne 'FAIL') {
    # The guard no longer catches the re-introduction -> the gate itself fails.
    throw "Negative fixture did not FAIL: false-completion protection has regressed."
}
```

### The negative-fixture idea (why the top rung is trustworthy)

A gate that only ever sees *good* inputs proves nothing — it could be a no-op. So
each gate ships a **negative fixture** that embodies the banned behavior, and the
gate is required to **FAIL** on it. The test of the guard is "does it still reject
the bad case?" If someone deletes the protection, the fixture stops failing, and
the meta-check turns that into a red build. The guard cannot rot silently.

This is the same pattern the project's other gates use: containment is proven by
feeding it a fixture whose path is a forbidden secret and confirming it is
flagged; Windows text-safety is proven by a fixture file with a non-ASCII byte
that must be rejected. Prove the FAIL direction, not just the PASS.

---

## Takeaways

- **Where a lesson lives is decided by blast radius**, not by convenience.
  Irreversible / security / false-Done risks may **not** rest in memory alone.
- **Climb until the cost is contained.** This one had to reach a hook/gate because
  its recurrence cost was lost work and a false Done.
- **Prove the guard with a negative fixture.** A gate that has never failed is not
  evidence; a gate that *still fails* on the re-introduced mistake is.
- **Implement the surface in the same session** the lesson is learned — do not
  defer it back into a memory note.
