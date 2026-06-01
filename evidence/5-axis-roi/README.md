# 5-axis ROI evidence

Driftless optimizes along five axes at once — it descends a gradient instead of
chasing one number:

1. **tokens** — how much context a unit of work costs.
2. **manager-intervention** — how many times a human has to step in.
3. **time** — wall-clock to get a change merged.
4. **money** — subscription/credit usage (framed as usage, not invented dollars).
5. **performance** — does the work actually pass the gates and behave.

The point of this folder is to show **how a before/after delta is captured** so a
reviewer can reproduce it — not to parade impressive numbers. Any number not yet
measured on a real run is labeled **UNVERIFIED**, and stays that way until a run
produces it.

## The unit of measurement: one ticket, before vs after

A delta is always a pair: the **same kind of work** measured **before** a change
and **after** it. The change is usually a skill or rule edit (for example,
compressing a session-hot instruction file, or promoting a lesson to a gate).
We record the per-axis cost of a representative ticket on each side.

| Axis | Metric we capture | How it is read |
| --- | --- | --- |
| tokens | tokens-per-ticket | Sum of context tokens to take one ticket from open to PR. |
| manager-intervention | interventions-per-merge | Count of human touches (questions answered, fixes, re-runs) per merged PR. |
| time | minutes-per-merge | Wall-clock from branch cut to merge. |
| money | usage-per-ticket | Subscription requests/sessions consumed (usage, not dollars). |
| performance | gate pass-rate | Fraction of gate runs that PASS without a retry. |

Each axis has a direction: tokens / interventions / time / money should go
**down**, performance should go **up**. A change is only an improvement if no
axis regresses past its watch trigger while the target axis improves — that is
the gradient, not a single-axis win.

## How a delta is recorded

A measured delta lives next to the overnight run that produced it (see
`../overnight-runs/`, the `five_axis` block) and, for a deliberate skill change,
alongside the harness fixture that proves it. The record shape:

```
axis:        tokens_per_ticket
before:      41000         # measured on the baseline ticket
after:       33500         # measured on the same ticket class after the change
unit:        tokens
ticket_ref:  "#215"        # what was changed
status:      UNVERIFIED | OBSERVED   # OBSERVED only once a real run produced both sides
note:        free text (what the change was, any caveat)
```

Until a real run fills both `before` and `after` from measured data, the record
stays `UNVERIFIED`. We do not promote an inferred or hoped-for number to a
headline.

## Reproducing it with the validation harness

The skill-optimization side of the loop is gated by a **local, LLM-zero
validation harness** (`scripts/Test-SkillOptValidationHarness.ps1`,
mirrored from the source project's skill-optimization gate). It is deliberately
static and repo-local: it does **not** run model loops, trainers, broad
benchmarks, paid API calls, recursive agents, or any host-global mutation. It
takes a baseline `SKILL.md` and a candidate `SKILL.md`, runs them through a
bounded fixture spec, and decides — deterministically — whether the candidate may
be adopted. That deterministic verdict is what makes a before/after skill delta
**reproducible** rather than a one-off anecdote.

```powershell
# Reproduce a skill before/after verdict against the committed fixtures
powershell.exe -ExecutionPolicy Bypass -File scripts/Test-SkillOptValidationHarness.ps1

# Validate a single candidate spec
powershell.exe -ExecutionPolicy Bypass -File scripts/Test-SkillOptValidationHarness.ps1 -SpecPath path/to/spec.json
```

Exit `0` = the candidate is valid (the fixture expectations are met); exit `1`
otherwise. Because the verdict is deterministic and repo-local, two reviewers on
two machines get the same answer for the same skill change — which is the whole
point of calling it *evidence*.

## Current status

The method above is implemented; the harness runs and gates skill changes today.
The **per-axis production numbers** (real tokens-per-ticket and
interventions-per-merge across many merged PRs) are still being captured into
`../overnight-runs/` and are **UNVERIFIED** here until a dated run publishes both
sides of the pair. The example deltas in the overnight-run template are
illustrative placeholders, not measurements.
