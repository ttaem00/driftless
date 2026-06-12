# Insight-inbox starter

This is a public-safe starter for the insight-inbox pattern. It is intentionally
small: a manual link queue, a review prompt contract, and an append-only
decision ledger.

Driftless ships this starter and the design pattern. It does not ship the
private app, private service launcher, real Discord integration, Chrome
extension, local tray, live tokens, or production queue.

## What This Starter Does

- Gives a non-developer manager one visible place for captured links.
- Keeps item status clear: inbox, fetched, triaged, reviewed, skipped,
  archived, or error.
- Records every reviewed or skipped item in a ledger so the same link is not
  re-decided from scratch.
- Keeps recovery explicit: removing a link from the active list means it is
  excluded from future review by default, and it can be restored from the
  archived section.

## What This Starter Does Not Do

- No real messaging token or webhook.
- No browser extension.
- No local tray or always-on service.
- No private repository dependency.
- No automatic public release.

## Files

- `queue/sample-links.md` - a tiny queue shape for captured links.
- `prompts/review-contract.md` - the fixed review instructions.
- `ledger/DECISIONS.md` - an append-only decision log.

## First Use

1. Add links to `queue/sample-links.md`.
2. Ask your agent to review the inbox using `prompts/review-contract.md`.
3. Move each result into `ledger/DECISIONS.md`.
4. Move mistaken captures to the archived section instead of deleting history.

## Upgrade Path

Only add real integrations after the manual starter proves the lifecycle:
capture, visible status, review, decision, recovery. Real messaging, browser,
or service integrations need explicit manager approval for credentials,
account setup, test posting, extension install clicks, and public release.
