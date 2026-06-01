# Sample overnight run (illustrative EXAMPLE)

> **This is a hand-written EXAMPLE, not a recording of a real run.** Every issue
> number, PR number, repo name, and count below is **EXAMPLE** data, invented to
> show the *shape* of one overnight session. It is a template for "what a real
> run looks like in plain language" — not fabricated live telemetry. A recorded
> GIF, when it exists, is a separate, manually captured artifact; this file is
> the text version you can read in the repo.

## The setup (EXAMPLE)

Imagine a small project — call it `notes-app` (EXAMPLE) — with a handful of open
issues: a date that renders wrong, an empty-state screen with no message, a flaky
test, a stale README command, and a request to "switch the database" that nobody
has scoped yet.

You are a non-developer. You do not read the code. Before bed, you open your
agent **inside the repo** and paste **one parent prompt**:

```text
Push every remaining ticket as far as you can overnight. Read the open issues,
split them into conflict-aware tickets, run workers in parallel, and turn what
is safely doable into branches and pull requests. Do not make any product,
billing, release, or irreversible decision yourself — ask me for those.
Report in the morning in plain language.
```

Then you go to sleep. That is the whole manager job.

## What the parent does overnight (EXAMPLE, summarized)

You do not have to watch this — it is here so you can see what the prompt set in
motion:

1. **Reads the situation.** Lists the open issues and any half-finished work,
   without inventing a "clean" status it did not verify.
2. **Splits into conflict-aware tickets.** Tickets that touch the same files run
   one-at-a-time; independent ones run as parallel workers.
3. **Runs workers in parallel**, each on its own branch, each turning a ticket
   into a pull request.
4. **Re-checks every worker's output itself** before trusting it — a worker
   saying "done" is not enough; the parent re-runs the checks.
5. **Refuses anything that is yours to decide** (see the refusal below) and
   leaves it for the morning report instead of guessing.

## The morning report you actually see (EXAMPLE)

This is the plain-language report a non-developer wakes up to. It opens with one
of the four manager labels, then the details. Everything here is **EXAMPLE**.

---

**tested/evidence** — 4 of 6 tickets are done and merged. 1 is waiting on a
decision only you can make. 1 is still in progress and will resume next run.

**Done (merged pull requests):**

- **PR #112 (EXAMPLE)** — Fixed the date showing one day off on the notes list.
  Verified by running the app and checking the rendered date. (issue #41)
- **PR #113 (EXAMPLE)** — Added a friendly "No notes yet — tap + to start"
  message to the empty screen, plus loading and error states. (issue #44)
- **PR #114 (EXAMPLE)** — Repaired the flaky test that failed about 1 in 5 runs;
  it now passes 20/20 locally. (issue #45)
- **PR #115 (EXAMPLE)** — Updated the README so the "start the app" command
  matches what the project actually uses now. (issue #47)

**Needs your decision (the agent REFUSED to do this on its own):**

- **issue #46 (EXAMPLE) — "Switch the notes database to a paid hosted service."**
  The agent did **not** do this. It is a **product + billing + irreversible**
  choice: it would sign the project up for a paid plan, move your existing notes
  to a new service, and could not be cleanly undone. Under the guardrails, the
  agent is required to stop and ask rather than spend money, move user data, or
  make a product call for you.
  - What the agent *did* do safely first: it scoped the work, wrote down two
    options (stay on the current free local database, or move to the hosted
    one), and noted the rough effort for each — so your decision is a yes/no, not
    homework.
  - **Your decision (plain yes/no):** Do you want to move to the paid hosted
    database? If yes, the agent will come back to you for the billing details
    before doing anything. If no, it closes the ticket and keeps the current
    setup. **Recommended: no for now** — the current database works and this adds
    a monthly cost. Risk if you say yes without review: **high** (money + moving
    your data).

**Still in progress (will continue next run, no action needed from you):**

- **issue #48 (EXAMPLE) — "Add a search box."** Partly built. The search works
  but does not yet handle an empty search cleanly, so it is **not** merged — the
  agent does not merge half-finished work. It left an exact note to itself for
  where to pick up, so the next overnight run continues instead of restarting.

**Blocked:** none this run.

**Summary counts (EXAMPLE):** merged 4 · needs your decision 1 · in progress 1 ·
blocked 0.

**Honesty note:** the checks above were run on **Windows** in this EXAMPLE.
macOS/Linux behavior for the same changes would be marked **UNVERIFIED** until
run there — the project keeps a host evidence matrix rather than claiming a pass
on an OS it did not test.

---

## Why the refusal matters

The single most important line in that report is the one where the agent says
**"I did not do this — here is your yes/no."** Paste-one-prompt automation is
only safe because the agent **stops** at exactly the things that are yours:
spending money, releasing publicly, moving or deleting user data, and any change
that cannot be cleanly undone. Everything routine — the git, the branches, the
pull requests, the re-checking — it owns. The decisions that cost you money or
cannot be taken back, it hands to you with a recommendation, not a fait accompli.

## What is real vs. illustrative here

- **Real (the method):** the one-prompt flow, conflict-aware ticket splitting,
  parallel workers becoming pull requests, the parent re-verifying its own
  workers, the four manager labels, and the hard refusal on money / product /
  irreversible / user-data decisions. These are how the loop actually behaves.
- **Illustrative (EXAMPLE):** `notes-app`, every issue/PR number, every count,
  and the specific tickets. They are invented to make the shape concrete. They
  are **not** a log of a live run on this repository.
