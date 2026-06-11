# Adopt external tools safely

The agent world moves fast, and every week there is a new "must-have" repo, MCP
server, or skill pack. Driftless is built to *resist* bolting those on by
reflex. This page is the short rule for bringing an outside idea in **without**
breaking what makes Driftless safe and lean.

You do not need to write any code. This is the rule your agent follows for you,
and the same rule you can read in one screen if you want to decide yourself.

> **One sentence:** borrow the *idea* in its smallest form; never copy a whole
> framework, and never let an outside tool reach past the fence.

---

## Why this matters for a non-developer

When you tell your agent "apply this cool repo," the risky part is invisible:
a tool can quietly want your global config, a paid API key, a database to run,
or permission to spawn other AIs. Any of those turns a small, free, private kit
into a heavy, costly, leaky one. The checklist below makes the agent **stop and
show you** before that happens — and the default answer to "install this extra?"
is always **No**.

## The Driftless principles (short, and grounded in known practice)

These echo well-known agent-engineering principles (e.g. the widely cited
*12-factor-agents* list — own your prompts, own your context, small focused
pieces, a human in the loop), adapted to Driftless's two reality checks:
**a non-developer owner** and **two mirrored profiles (Claude + Codex)**.

1. **Smallest form wins.** Adopt one idea as a doc line, a checklist item, or a
   tiny script — not a framework. If it needs new infrastructure, it is probably
   too big for day one.
2. **Ask before installing; default No.** MCP servers, plugins, dependencies,
   and packages are never installed silently. The agent explains what and why,
   then waits for your yes.
3. **The fence is not optional.** Nothing you adopt may read or write your
   host-global config (`~/.claude`, `~/.codex`), your secrets (`.env`, `.ssh`,
   keys, browser data), or anything outside this project's isolated home.
4. **No money, no recursion by default.** A tool that needs a paid API, captures
   to the cloud, or spawns other agents is rejected unless you explicitly decide
   otherwise.
5. **One edit, both profiles.** If the adopted idea is shared, it lives in the
   shared tier so Claude and Codex both get it from one place — never copied into
   one profile and forgotten in the other.
6. **Honest labels.** If the agent has not actually checked a repo's license,
   activity, or behavior, it says `UNVERIFIED` — it does not guess that something
   is safe.

## How the agent vets a repo (the lean checklist)

There is a shared skill, **`adopt-external-tool`**, that runs a one-screen vet
before applying anything. It is deliberately *not* a scanner you have to install
— it is a checklist the agent walks through, then closes with one verdict:

- License public-safe? • New infra / paid / network? • Touches host-global or
  secret paths? • Inline secrets? • Spawns peer/recursive AI? • Real ROI for this
  project? • What is the *smallest* form?

…then one of: **ADOPT_SMALL**, **PILOT_ONLY**, **WATCH_LATER** (with a re-check
trigger), **REJECT** (with a reason), or **UNVERIFIED** (with what was not seen).
The verdict is appended to `docs/external-repo-review.md` so the same repo is
never re-litigated from scratch.

If candidates arrive as a *stream* — links shared from your phone all week —
the [insight-inbox pattern](./insight-inbox-pattern.md) industrializes this
same vet: a messenger channel as the capture inbox, a cheap batched triage in
front of the expensive deep review, and every verdict recorded in a ledger.

Before the agent treats an external skill, repo, plugin-like packet, or MCP
setup as adoption-ready, it also runs the public pre-adoption gate:

```powershell
pwsh.exe -ExecutionPolicy Bypass -File scripts/Test-ExternalAdoptionSafetyGate.ps1 -CandidatePath path\to\candidate
```

That gate blocks direct adoption when static triage sees unresolved arbitrary
execution, download-pipe-exec, host-global or secret references,
credential/cloud/billing/MCP surfaces, daemon startup, or a missing pilot
closeout decision. It does not install anything and it is not a malware detector;
it is the "stop before adopting" check.

## Where the proof lives

If the agent does adopt something, it proves the fence held by running the
gates — the containment guard (`Test-Containment.ps1`), the mirror-parity gate
(`Test-ProfileMirrorParity.ps1`), and, for any Windows script it touched, the
text-safety gate. If it could not run them, it reports `UNVERIFIED`, not "done."

> Prior art, not imported wholesale: the *12-factor-agents* principles are cited
> here as grounding. Driftless does not vendor that document; it keeps its own
> short rule so the hot context stays small.
