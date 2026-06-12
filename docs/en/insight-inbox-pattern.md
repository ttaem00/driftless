# The insight-inbox pattern: from a shared link to a recorded decision

You see a promising tool, repo, or technique on your phone. Two weeks later you
cannot say whether it was ever evaluated, adopted, or rejected — so it gets
reviewed again, or worse, silently lost. This page records a design pattern
that fixes the whole path: reuse a messenger channel you already have as a
cross-device **insight inbox**, put an automated **adoption-review pipeline**
behind it, and end every captured link in a **decision ledger**.

> **One sentence:** capture must be effortless, review must be automatic, and
> every captured link must end in a recorded decision — because the real
> friction was never the bookmark click.

Driftless does not ship this pipeline. This page documents the design — proven
in a private companion deployment (June 2026) — so an agent can reproduce it
for your own projects in the smallest form that fits. The safety half of the
same design lives in
[Feeding untrusted web content to an LLM, safely](./untrusted-content-llm-safety.md).

## Public starter vs private companion service

Driftless ships the pattern, the public starter, and the safety gates. It does
not ship the private app, private service launcher, real Discord integration,
Chrome extension, local tray, live tokens, or production queue. Public users
should start from
[`examples/insight-inbox-starter/`](../../examples/insight-inbox-starter/) and
the shared
[`insight-inbox-starter`](../../profiles/shared/skills/insight-inbox-starter/SKILL.md)
skill.

The starter is deliberately small: a manual markdown queue, a review prompt
contract, and an append-only decision ledger. That is enough to prove the
load-bearing lifecycle before adding private integrations:

- captured links are visible;
- wrong captures can be removed from active processing and restored later;
- partial reads and fetch failures are not hidden;
- skipped or rejected links still produce a ledger decision.

Any real messaging, browser, local service, credential, or public release lane
belongs outside this public starter until a manager explicitly approves that
private implementation work.

---

## The root cause: capture was never the friction

The obvious diagnosis is "saving links is annoying, build a better capture
tool." The deployment that proved this pattern started there and found the
diagnosis wrong. The bookmark click was cheap. The expensive parts were:

1. **Manual LLM handoff, per link.** Every captured link still required a
   human to open an agent session and paste the link in.
2. **Re-specifying the review procedure, every time.** "Check whether this is
   worth adopting for my project" had to be re-explained — criteria, output
   shape, verdict scale — in each new conversation.
3. **No decision ledger.** The verdicts evaporated. The same link got
   re-reviewed weeks later, and nobody could remember why something was
   rejected the first time.

Three design consequences follow directly:

- **Capture surfaces are pluggable and cheap.** A messenger message, a
  one-line command — anything that takes a URL. They are entry points, not
  the product.
- **The review procedure is a fixed, versioned prompt contract.** It lives in
  a file under version control, not in someone's chat history. Changing the
  criteria is a reviewed edit, not a retyped paragraph.
- **Every item ends in a recorded decision.** Including "skipped" and
  "rejected" — a decision you cannot look up later is a decision you will pay
  for twice.

## Reuse a messenger channel; do not build a browser extension first

The cross-device capture problem is already solved by software you run every
day. A private channel in a messenger you already use (Discord, Slack,
Telegram — anything with a phone share sheet and a read API) gives you:

- **Mobile capture for free.** The phone share sheet posts to the channel in
  two taps. No new app, no new habit.
- **Zero maintenance.** No store review, no browser-update breakage, no
  extension permissions to defend.
- **A natural queue.** The pipeline reads the channel with a cursor; messages
  it has not seen yet *are* the inbox.

A browser extension was the reflex first idea, and it was deliberately put on
the backlog instead — in Driftless terms, a **WATCH_LATER with an explicit
re-check trigger** (see
[Adopt external tools safely](./adopt-external-tools-safely.md)): build it
only if capture friction is still felt after two weeks of real pipeline use,
or if page metadata (selected text, thread context) becomes necessary. The
deeper reason: an extension improves only *capture*, which was never the root
friction. It does nothing for the handoff, the procedure, or the ledger.

## The pipeline behind the channel

```
share to channel ──> sync ──> fetch content ──> triage (cheap, batched)
                                                    │
                                     not relevant ──┴──> skipped  (recorded)
                                                    │
                                                deep review (expensive)
                                                    │
                                          digest + decision ledger
```

Each stage is a small script with one contract; a failing stage logs and the
run continues, so one bad item never blocks the queue. Items are deduplicated
by hashing a canonicalized URL, so the same link shared twice is one item.
Stages that need credentials (channel read, digest webhook) **skip gracefully
when unconfigured** — the pipeline degrades to manual capture instead of
demanding secrets.

Item state is a small machine, persisted per item:

```
inbox -> fetched -> triaged -> reviewed
                \-> skipped   (triage: not relevant — still recorded)
any   -> error    (after bounded retries; resettable, never silent)
```

### Read enough, and say what you did not read

A captured link is often only the *entry point* of the insight — the substance
continues in author thread replies, quoted posts, or linked articles. The
fetch stage therefore does **bounded depth-1 link expansion** (follow a few
content links found in the fetched body, each size-capped) and records a
**completeness flag** (`ok` or `partial`) plus the list of links it did *not*
read. The review prompt is required to label facets that depend on unread
material as **UNVERIFIED instead of guessing** — the same evidence honesty
rule Driftless applies everywhere else (see the
[host evidence matrix](./host-evidence-matrix.md) for the repo-level version).
Completeness heuristics never block the pipeline; they only inform the label.

## The two-stage cost gate

Deep adoption review is the expensive stage, and most captured links do not
deserve it. So the pipeline puts a cheap gate in front:

- **Stage 1 — triage, batched, on a cheap model.** Many items go into *one*
  LLM call (id, URL, note, first ~1,500 characters each). Output: relevant or
  not, target project, type, priority, one-line reason. Items judged not
  relevant become `skipped` — a recorded verdict with a reason, never a
  silent drop.
- **Stage 2 — deep review, per item, on a strong model.** Only survivors,
  highest priority first, capped per run. Output: a full adoption report with
  a verdict line.

Measured in the proving deployment (June 2026): a whole triage batch cost
about **$0.02**, while one deep review cost about **$0.22** — roughly an
order of magnitude per item before batching is even counted. Single
deployment, one month, model prices change; treat the shape as the lesson,
not the digits. The same gate also protects *free-tier daily quotas* when the
engines are subscription or free-pool based — budget is budget.

The general rules this instance proves:

1. Put the cheap classifier in front of the expensive judgment.
2. Batch the cheap stage; the expensive stage gets a per-run cap and a
   priority order.
3. A cost gate must record what it drops. `skipped` is a verdict with a
   reason in the ledger, so saving money never silently loses an insight.

## The decision ledger

Every reviewed or skipped item appends one row to an append-only markdown
table: date, item id, verdict, URL, project, one-line detail. The verdict
scale used by the proving deployment maps directly onto the Driftless
adoption verdicts from [Adopt external tools safely](./adopt-external-tools-safely.md):

| Pipeline verdict | Meaning | Driftless equivalent |
|---|---|---|
| A | adopt now, smallest form | ADOPT_SMALL |
| B | real-use pilot first | PILOT_ONLY |
| C | adopt only if a named condition holds | conditional ADOPT_SMALL |
| D | backlog, with an explicit re-check trigger | WATCH_LATER |
| E | reject, with the condition that would reopen it | REJECT |

A report must also name the *next action* and weigh the risk of delaying
adoption against the risk of forcing it — the ledger row is a decision, not a
book report. The ledger is the same idea as this repo's
`docs/external-repo-review.md` append-only verdict log: **never re-litigate a
decision from scratch**; look it up, and re-open it only when its recorded
trigger fires.

## Where this fits in Driftless

Driftless already owns the *single-repo* decision: the `adopt-external-tool`
skill vets one candidate, and `docs/external-repo-review.md` records the
verdict. The insight-inbox pattern is the **conveyor belt in front of that
decision** — it turns a stream of phone-captured links into batched,
cost-gated, ledger-recorded applications of the same verdict scale. If you
adopt the pattern, the smallest-form rule applies to it too: start with a
channel, three scripts, and a markdown ledger. The state machine and the cost
gate are the load-bearing parts; everything else is replaceable.

Korean version of this page:
**[인사이트 인박스 패턴](../ko/인사이트인박스패턴.md)**.
