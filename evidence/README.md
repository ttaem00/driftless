# Driftless evidence

This folder is the part a fresh-clone reviewer can **inspect** instead of taking
on faith. The honest worry about any "self-improving agent" project is that the
proof lives in private runtime state you cannot see. Here it does not. Everything
in this folder is public-safe and committed.

What this folder is NOT: it is **not** the live runtime. The real agent runs
against a repo-local, gitignored config home (`.runtime/`), and that directory is
never committed (containment). So this folder holds the **shapes, harnesses, and
worked examples** that let you reproduce and check the claims yourself — not a
dump of private session data.

## The headline claim: this repo built itself

Driftless is overnight self-improving maintainer automation for Claude **and**
Codex. The strongest evidence is the project's own history: the work was driven
by the same overnight autonomous loop the product ships.

These headline numbers were measured on the **development runtime** Driftless
was extracted from (a private, containment-sensitive runtime), so they are the
*method's* proof, self-attested. The part a reviewer can verify with **no trust
required** is this public repo's own, growing graph. The two are kept side by
side, honestly, in **[loop-log.md](./loop-log.md)** — read it first so the
numbers below are never mistaken for this repo's day-one graph.

Development-runtime numbers at extraction (real, measured):

- **113 merged pull requests** — each one a unit of self-built work.
- **94 issues** — the work was ticketed before it was edited (issue-before-edit).
- **114 commits** on the default branch.
- **39 Claude skills + 34 Codex skills** — two tool profiles kept in mirror.
- A **decision register** practice where every non-trivial choice is recorded
  with a decider tag (`[manager]` / `[agent]`) and a rationale, so a reviewer can
  trace *why*, not just *what*. The source project keeps this register **private**
  (it holds development decisions specific to that runtime), but the same decider
  tags + rationale appear inline in the public issue and PR bodies.

The loop that produced this: an **issue** is opened, a **branch**
(`agent/issue-<n>-<slug>`) is cut, a **pull request** is raised, gates run, and a
human approves the merge. Issues -> branches -> PRs -> merges, repeated overnight.

## What lives here

| Folder | What it shows |
| --- | --- |
| `overnight-runs/` | The SHAPE of one dated overnight run: issues surveyed -> N worker subagents -> M merged PR numbers -> the risk decisions the agent REFUSED and escalated to a human. Includes a labeled EXAMPLE template until real runs are captured here. |
| `5-axis-roi/` | How a before/after measured delta is captured per axis (tokens-per-ticket, interventions-per-merge, time, money, performance) and how the validation harness reproduces it. Not-yet-measured numbers are labeled UNVERIFIED. |
| `lesson-ladder/` | One concrete recurring mistake climbing the promotion ladder memory -> skill -> hot rule -> hook -> gate, ending in a gate that now FAILS any re-introduction (a negative fixture). |

## How to check it yourself

1. Open the source project's GitHub graph and confirm the merged-PR / issue /
   commit counts above. The numbers are public.
2. Open any merged PR or issue body and find the dated decision lines tagged
   `[manager]` / `[agent]` with a rationale, then follow the decision to its
   issue and PR. (The source project's full decision register is private; the
   same tagged decisions surface inline in these public threads.)
3. Run the containment gate on a fresh clone — it must PASS, proving the public
   tree carries no secret, no host-global `~/.claude` / `~/.codex` content, and
   no `.runtime/` state:

   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File scripts/Test-Containment.ps1 -AllFiles
   ```

4. Run the skill-optimization validation harness against its fixtures to
   reproduce a before/after skill delta locally (see `5-axis-roi/`).

## Containment note

Nothing in this folder contains a secret, a `.env`, an `.ssh` key, a browser
profile, a private key, or any content from a host-global agent home or a
gitignored `.runtime/` directory. The example artifacts below are
hand-authored templates, clearly labeled, with no real account or session data.
The containment gate (`scripts/Test-Containment.ps1`) treats this whole folder
like any other and must pass on it.

- **real-use-verification.md** — a measured fresh-clone non-dev run (clone -> install -> both isolated homes -> containment PASS) end-to-end in ~16s. The 5-axis TIME proof + onboarding-works check.
