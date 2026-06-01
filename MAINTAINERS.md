# Maintainers

## Who maintains Driftless

Driftless is maintained by a **human operator-architect** who designs the goals,
sets the guardrails, and decides what ships — and by the **AI agents the project
itself ships** (Claude Code and OpenAI Codex), which do the implementation labor
under that human's direction.

- **Human maintainer / operator:** [@mizan0515](https://github.com/mizan0515) —
  designs and directs the loop, owns every product, priority, release, and
  destructive/irreversible decision, and approves what merges. A non-developer by
  background, which is the whole point: Driftless exists to let a person who
  cannot hand-write the code still maintain real software safely.
- **Agent labor:** the overnight autonomous loop (the same one this repo ships)
  proposes work, opens branches, writes changes, runs the gates, and prepares
  pull requests. It is *labor under a maintainer*, never an unsupervised
  committer: risk, permission, billing, public-release, and destructive actions
  are always escalated to the human.

## Why we say this plainly

The point of Driftless is that the loop is real enough to maintain real
software, including itself. Hiding the agent's role would undersell the thesis;
overstating "fully autonomous" would oversell the safety. The honest shape is:
**a human maintainer directs an agent that does the labor, behind containment
and human-only gates.** That is on-thesis for an open agent ecosystem (MCP +
AGENTS.md), not a disclaimer.

## How decisions are recorded

Every meaningful decision — manager (human) and agent — is recorded with its
rationale, so anyone can review or challenge it. New maintainers or contributors
read that record first and treat it as the project's source of truth.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for how to reproduce the loop and
propose changes. Issues and pull requests are welcome; every change runs the
safety gates (containment, text-safety, mirror-parity) before it can merge.
