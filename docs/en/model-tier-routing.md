# Cost-aware model-tier routing

Driftless lets a maintainer talk about stable work roles rather than provider
catalogs. The shared data contract is
[`profiles/shared/schemas/model-tier-routing.json`](../../profiles/shared/schemas/model-tier-routing.json).
It names three replaceable capability tiers: `fast`, `value`, and `frontier`.
The example aliases in that file are deliberately generic. Availability, price,
latency, and cache behavior are volatile inputs to measure at use time, not
facts embedded in a hot instruction.

## Choose the cheapest sufficient tier

| Role | Default tier | Typical work | Budget |
| --- | --- | --- | --- |
| `scout` / `mechanical_worker` | `fast` | File scans, summaries, formatting, routine test runs | compact / minimal |
| `implementation_worker` / `reviewer` | `value` | A bounded edit, focused diagnosis, normal review | focused / medium_execution |
| `final_authority` | `frontier` | Exception-only security, architecture, release, or final cross-context judgment | extended / high_judgment |

`frontier` is never the inherited default for an ordinary child. Use it only
when the issuer records a named risk, observed quality evidence, and an
escalation reason. If that condition ends, the next bounded task returns to the
role default. If an alias is unavailable, pick an available alias in the same
tier and record why; lack of availability never silently promotes a task.

## Child issuance record

Every issued child records these fields before work starts:

```yaml
routeRole: implementation_worker
selectedModel: value-example
contextBudget: focused
reasoningBudget: medium_execution
escalationReason: not_escalated
```

For a `frontier` exception, `escalationReason` must name one of the contract's
allowed reasons and the issuing evidence must state the concrete risk or quality
failure. The record is provenance, not a provider credential, endpoint, price,
or account setting.

## Cost, quality, latency, cache, and availability trade-offs

- Start cheap when a result is easy to verify or safely retry; this limits cost
  and usually lowers latency.
- Move to `value` for a bounded implementation only when the task needs more
  reliable synthesis than a scan or mechanical action.
- Use `frontier` only for the documented exception; cache hits, availability,
  and measured quality can affect the chosen alias within a tier, but cannot
  erase provenance or justify a cross-tier escalation by themselves.
- Roll back by changing the alias mapping or role mapping in the one shared
  JSON contract. Consumers keep their stable role names, so no profile-specific
  workflow needs to change.

Run the executable contract and fixture gate with:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-ModelTierRoutingContract.ps1 -Root .
```

The gate covers silent frontier inheritance, stale provider-style literals,
missing issuance provenance, and unjustified escalation. It makes no model
call, reads no account state, and does not install or configure a provider.
