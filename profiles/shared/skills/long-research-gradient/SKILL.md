---
name: long-research-gradient
description: >
  Long research gradient skill for public Driftless profiles. Use when a
  maintainer or student asks for long-running research, deep research, repeated
  research sprints, benchmark scans, or adopting ideas from Open Deep
  Research/GPT Researcher/Deep Agents/mem0/InternAgent/STORM. It turns broad
  research into evidence sprints and closes every sprint with gradient
  improvements to tokens, intervention, time, money, quality, and recurrence
  risk. Trigger: "long research", "deep research", "research sprint", "gradient
  closeout", "Open Deep Research", "GPT Researcher", "Deep Agents", "mem0",
  "InternAgent", "STORM".
---

# Long Research Gradient

Manager outcome: long research becomes small evidence-backed sprints, and each
sprint leaves the agent workflow cheaper, clearer, and less manager-dependent.

## Student Fast Path

A non-developer can start with one sentence:

```text
long research: <topic or question>
Ask me only real decisions; handle research, evidence, next action, and gradient closeout.
```

Korean-friendly shorthand also works:

- `장기연구: <주제>`
- `/ deep research: <question>`
- `deep research: <question>`
- `이 주제 오래 조사해서 결론 내줘`
- `오픈소스 후보를 research sprint로 검증해줘`

For a public-safe student-facing example, read
`references/student-fast-path.md` only when an example output or UX fixture is
needed.

If the request is vague, infer a safe first sprint and state assumptions. Ask
only one short meaning-level question when the answer changes product direction,
credentials, billing, public release, destructive action, host-global promotion,
or user-data handling.

## Required Closeout UX

Every use must end with `이번 경사하강`:

- `kept`: what stayed as-is because it is already cheap and useful.
- `changed now`: safe repo-local skill/prompt/script/hook/doc/hot-rule change
  made this cycle.
- `issue/watch`: follow-up created or reused when evidence is not ready.
- `saved tokens/time/intervention`: concrete expected saving, or `UNVERIFIED`.
- `next sprint`: continue, pivot, stop, or ask one human-only question.

If no optimization was possible, say exactly why. Do not silently skip closeout.

## Why This Is Shared

The useful public-safe pattern is not an external agent dependency. It is a
workflow:

- Open Deep Research: configurable search/model/tool adapters.
- GPT Researcher: planner -> executor -> cited report.
- Deep Agents: planning, context management, files, skills.
- mem0: promote only verified findings into memory.
- InternAgent / Deep Researcher Agent: hypothesis -> experiment -> result loop.
- STORM: outline-first synthesis and citation-heavy reports.

Use the pattern. Do not require a specific provider, paid API, MCP server,
credential, or recursive AI agent.

## Sprint Loop

1. Charter: root question, visible success criteria, allowed sources, forbidden
   sources, freshness needs, and stop condition.
2. Plan: 3-7 subquestions and the decision each subquestion should unlock.
3. Gather: prefer primary sources, official docs, papers, repo metadata, and
   local command evidence.
4. Synthesize: separate `Observed`, `Inferred`, `UNVERIFIED`, `Blocked`, and
   `Next action`.
5. Checkpoint: save safe repo-local notes and evidence; do not save secrets,
   credentials, host-global paths, browser profiles, or private user data.
6. Close out: decide continue, pivot, stop, or ask a true manager-only question.

## Gradient Closeout

After every meaningful sprint, improve the workflow if safe:

- Tokens: can repeated explanation move to a skill, prompt, template, or script?
- Manager intervention: did the user have to choose tools, commands, or gates?
- Time: can repeated waiting or checks become a script/test/gate?
- Money: did the workflow add unnecessary paid or metered surfaces?
- Quality: did evidence, validation, or source quality fail repeatedly?
- Recurrence: should this become a lesson, skill edit, hook, hot rule, or issue?

Automatic means repo-local, bounded, and validated. It does not mean uncontrolled
self-mutation. Host-global changes, credentials, billing, public release,
destructive actions, user data transfer, and recursive/peer AI require explicit
human approval.

## Promotion Order

1. script/test/gate for repeated validation;
2. prompt/template for repeated input shape;
3. skill for conditional workflow;
4. hook for reliable automatic detection;
5. hot rule only for short always-needed rules;
6. docs for public explanation;
7. follow-up issue when evidence is not ready.

## Report

```markdown
built/inspected:
- <sprint or workflow improvement>

tested/evidence:
- <sources, commands, checks, dates, or static-only UNVERIFIED>

manager run/paste:
- <none unless a true human approval is needed>

blocked/unverified:
- <missing evidence or approval gate>
```
