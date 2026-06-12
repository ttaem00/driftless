# Review Contract

Use this contract for each active queue item.

## Inputs

- item id
- link
- manager note
- fetched text or a clear `UNVERIFIED` note if the content was not fetched
- known unread links or missing context

## Required Output

1. Verdict: `ADOPT_SMALL`, `PILOT_ONLY`, `WATCH_LATER`, `REJECT`, or
   `UNVERIFIED`.
2. Reason: one plain-language sentence.
3. User impact: who benefits and what gets easier.
4. Risk: what could go wrong if adopted too early.
5. Next action: the smallest safe step.
6. Ledger row: one row ready to append to `ledger/DECISIONS.md`.

## Rules

- Do not guess from unread material. Mark those parts `UNVERIFIED`.
- A skipped or rejected item is still a decision and must get a ledger row.
- If a link is archived, it is excluded from future review by default.
- Do not request credentials, tokens, billing, browser install clicks, or public
  release inside this public starter.
