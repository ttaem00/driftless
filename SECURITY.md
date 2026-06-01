# Security Policy

Driftless ships AI agents that do real work (git, GitHub, file edits) on your
machine, so the safety boundary matters as much as the feature set. This page
says how to report a problem and what the project guarantees.

## Supported version

| Version | Supported |
|---|---|
| v0.1.0 | yes |

Driftless is **v0.1.0, day one**. There is only one supported line; security
fixes land on the latest release.

## Reporting a vulnerability

Please report privately first — do not post a working exploit in a public issue.

- **Preferred:** open a [GitHub Security Advisory](https://github.com/mizan0515/driftless/security/advisories/new)
  (private, visible only to maintainers until a fix ships).
- **If advisories are unavailable:** open a regular issue titled clearly with a
  `[security]` prefix and **no exploit details in the body** — just say a
  security report is ready and a maintainer will move it to a private channel.

Tell us what you did, what you expected, and what actually happened. A
maintainer ([@mizan0515](https://github.com/mizan0515)) triages security reports
ahead of normal issues. There is no bug-bounty program; this is a small,
volunteer-maintained project, and we will still take a real report seriously.

## What the project guarantees

**Containment.** Driftless runs each agent against an isolated config home
**inside the cloned repository**. It never reads or writes your machine's
host-global agent settings, and it never touches a forbidden path —
environment-secret files, SSH key directories, secret stores, private keys, or
browser profiles. This is not a promise on trust: a gate proves it.

```powershell
.\scripts\Test-Containment.ps1
```

The forbidden surface is declared once in a shared contract that both profiles
consume. Plant one violation — reference a host-global agent home, or commit a
key — and the gate returns **FAIL**, blocking the change before it ships. The
gate is proven in both directions, so it must still FAIL on a planted
violation; disabling the check is itself caught.

**Human-only gates for risky actions.** The agent escalates rather than decides
when an action is risky, irreversible, or touches credentials — public release,
billing/quota, destructive or history-rewriting git operations, host-global
promotion, and transfer of user data are all escalated to the human maintainer.
The agent does the labor; a human owns every irreversible decision.

## What is out of scope

- **Your own secrets and credentials.** Driftless never reads them, but it also
  cannot protect a secret you paste directly into a prompt or commit by hand.
- **Third-party services.** Vulnerabilities in the agent CLIs themselves
  (Claude Code, OpenAI Codex) or in GitHub belong to those vendors; report
  those upstream.
- **Host evidence.** Behavior is verified per operating system. See the
  [host evidence matrix](./docs/en/host-evidence-matrix.md); items marked
  `UNVERIFIED` on an OS are not yet proven there.
