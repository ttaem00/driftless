---
name: insight-inbox-starter
description: >
  insight-inbox-starter: Use when a manager asks to start, copy, adapt, or
  productize the public-safe insight-inbox pattern from Driftless, without
  installing or implying the private companion app. Trigger: "insight inbox
  starter", "insight-inbox pattern", "link review inbox", "captured links",
  "decision ledger", "make an inbox for links", "public starter".
---
## Improvement Principle

Use root-cause analysis and root-cause fixes, not symptom patches. The root
goal is not "save links"; it is "captured links reliably become visible,
reviewed decisions that can be recovered later." Generalize through lifecycle,
recovery, evidence, and manager-safe setup principles. Avoid cloning a private
service, adding credential flows, or special-casing one messenger unless the
manager explicitly approves a private implementation lane.

Prefer principle-based guidance and design principles over one-off rules. Avoid
spec/case overfitting: do not make a starter that only works for one channel,
one folder, one token shape, or one captured-link mistake.

# Insight-inbox starter

This skill helps an agent turn Driftless's public insight-inbox pattern into a
small, safe starter in the target project. Driftless ships the pattern and a
starter contract only. Driftless does not ship the private app, private service
launcher, real Discord integration, Chrome extension, local tray, live tokens,
or production queue.

## Public-safe boundary

Default to the smallest local starter:

- a manual markdown queue for links;
- an append-only decision ledger;
- a fixed review prompt contract;
- a plain status note that tells the manager what is waiting, reviewed, skipped,
  or blocked.

Do not add secrets, real webhook shapes, bot tokens, extension permissions,
local machine paths, private repo URLs, or claims that Driftless provides the
private service. If the manager wants a real Discord or Chrome integration,
record that as a separate private implementation lane with manager-only gates
for credentials, account setup, posting tests, browser install clicks, and
public release.

## User journey contract

Design from the manager's and end user's view:

1. Capture: the user can add a link without knowing repo, branch, port, token,
   or shell commands.
2. Status: the first screen or first note says what needs attention now.
3. Review: each item has an explicit state: inbox, fetched, triaged, reviewed,
   skipped, archived, or error.
4. Recovery: removing from the active list excludes future processing and has a
   restore path.
5. Evidence: partial reads and failed fetches are visible instead of hidden.
6. Decision: every skipped or reviewed item lands in the ledger with a reason.

## Starter files to create

Create or adapt these files in the target project unless equivalents already
exist:

- `examples/insight-inbox-starter/README.md` or a project-local README section;
- `examples/insight-inbox-starter/queue/sample-links.md`;
- `examples/insight-inbox-starter/ledger/DECISIONS.md`;
- `examples/insight-inbox-starter/prompts/review-contract.md`;
- an optional `STATUS.md` with "Now / Waiting / Needs manager decision".

Keep all examples placeholder-only. Use labels such as `WEBHOOK_PLACEHOLDER` or
`CHANNEL_PLACEHOLDER` only when a placeholder is needed; do not show credential
formats or real endpoint shapes.

## Closeout

Before reporting Done, verify:

- the starter does not mention a private repo URL, local machine path, real
  token/webhook shape, Chrome extension install path, or live service port;
- the docs say Driftless ships a pattern/starter, not the private app;
- the ledger includes skipped/rejected states, not only successful reviews;
- active-list removal is described as future-processing exclusion plus recovery;
- containment and any repo-specific public-safety gate passed.
