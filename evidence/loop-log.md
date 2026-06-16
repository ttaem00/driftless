# Loop log — the method's record, side by side

Driftless makes two different claims, and it is honest about which evidence
backs each. This log keeps them side by side so the headline numbers are never
mistaken for this public repo's own (day-one) graph.

## Two columns, two kinds of evidence

| | Development runtime (at extraction) | Public Driftless (since day one, live) |
|---|---|---|
| **What it is** | The private runtime that Driftless was extracted from. It ran this exact loop on its own backlog for weeks. | This public repository. Its own graph starts at v0.1.0 and fills as the loop runs in the open. |
| **Can a reviewer click into it?** | No — it is a private, containment-sensitive runtime. The numbers are the method's proof, self-attested. | **Yes.** The public PR and issue graph is clickable. Local gate evidence is reported per run; hosted CI was retired and is not used as current proof. |
| **Merged PRs** | 113 — [redacted list of all 113](./development-runtime-prs.md) | grows — see [merged PRs](https://github.com/mizan0515/driftless/pulls?q=is%3Apr+is%3Amerged) |
| **Issues** | 94 | grows — see [issues](https://github.com/mizan0515/driftless/issues?q=is%3Aissue) |
| **Commits** | 114 | grows — see [commits](https://github.com/mizan0515/driftless/commits/main) |
| **Agent skills** | 73 (39 Claude + 34 Codex) | 16 shipped here (12 shared + 2 tool-specific + 2 standalone), mirror-parity-gated |

## Why both columns exist

- The **left column** proves the *method* works at scale: a non-developer ran
  the loop and it produced a real, sustained maintenance graph. It is honest but
  not independently verifiable, because the runtime is private (making it public
  would break the containment guarantee that is itself a selling point).
- The **right column** is the part a skeptical reviewer can verify with no trust
  required: this repo maintains itself in the open. It starts small on purpose —
  small, real, dated, issue-linked, gate-green changes beat a flood of make-work.

The point is not the size of either column. It is that the **mechanism is
reviewer-verifiable here** (the gates run on the public repo in both directions),
and the **track record is filling in public** rather than hidden.

## Public self-maintenance, dated

The loop's first public work on this repo:

- Declared the maintainer role (MAINTAINERS.md + README + CONTRIBUTING) — PR #5.
- Argued the ecosystem role explicitly — PR #6.
- Added this loop log — this change.
- Added public validation gates. Earlier hosted CI proof is historical; current
  merge evidence uses repo-local PowerShell gates and the no-Actions workflow
  gate.

Each was an issue, on its own branch, gate-green, merged via PR. Browse the live
graph from the links in the table above to watch it continue.
