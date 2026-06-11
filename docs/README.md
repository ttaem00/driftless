# Driftless docs

A map of the documentation. New here? Start at the top. KO links are in
parentheses where a Korean mirror exists.

## Start here (non-developer)

- **[What is Driftless](./en/what-is-driftless.md)** (한국어: [드리프트리스란](./ko/드리프트리스란.md)) — the idea in plain language.
- **[5-minute quickstart](./en/quickstart.md)** (한국어: [빠른 시작](./ko/빠른시작.md)) — clone → install → one prompt → morning report.
- **[Apply it to your own agent](./en/apply-to-your-agent.md)** — say "apply this repo to me" and the agent sets it up.

## How it works

- **[Single-source two-profile mirror](./en/single-source-mirror.md)** — one edit improves both Claude and Codex.
- **[Codex and Claude](./en/codex-and-claude.md)** (한국어: [코덱스와 클로드](./ko/코덱스와클로드.md)) — how each tool uses Driftless, and which tool for which job.
- **[How Driftless learns](./en/how-driftless-learns.md)** (한국어: [어떻게 학습하나](./ko/드리프트리스는어떻게학습하나.md)) — the lesson-promotion ladder, the five axes, per-tool mistake learning.
- **[Lesson-promotion ladder](./en/lesson-promotion-ladder.md)** — memory < skill < hot rule < hook < gate.
- **[Compiled context wiki](./en/compiled-context-wiki.md)** — generate a local markdown wiki for recurring repo context without paid APIs or bundled apps.

## Safety

- **[Guardrails](./en/guardrails.md)** (한국어: [안전장치](./ko/안전장치.md)) — containment, ask-before-install, human-only escalation.
- **[Untrusted content → LLM, safely](./en/untrusted-content-llm-safety.md)** (한국어: [비신뢰 콘텐츠 LLM 안전](./ko/비신뢰콘텐츠LLM안전.md)) — the hardening checklist for headless LLM calls over fetched web content: no tools, sandbox cwd, injection fencing, SSRF and webhook guards.
- **[Host evidence matrix](./en/host-evidence-matrix.md)** — exactly what is verified on which OS (honest UNVERIFIED labels).
- **[SECURITY.md](../SECURITY.md)** — how to report a vulnerability; the containment guarantee.

## Extend

- **[Adopt an external tool safely](./en/adopt-external-tools-safely.md)** (한국어: [외부 도구 안전 도입](./ko/외부도구안전도입.md)) — vet a repo before applying it.
- **[The insight-inbox pattern](./en/insight-inbox-pattern.md)** (한국어: [인사이트 인박스 패턴](./ko/인사이트인박스패턴.md)) — a messenger channel as a cross-device capture inbox, a two-stage cost-gated review pipeline behind it, and a decision ledger at the end.
- **[12-Factor Agents, read through Driftless](./en/twelve-factors-driftless.md)** (한국어: [12요소로 본 드리프트리스](./ko/12요소.md)) — an honest factor-by-factor adoption of the HumanLayer 12-factor principles: what Driftless already does well vs. partially.
- **[CONTRIBUTING](../CONTRIBUTING.md)** — the one rule: every change passes the gates.

## Evidence (this repo maintains itself)

- **[evidence/](../evidence/)** — the loop log, the redacted development-runtime PR
  list, the 5-axis ROI shape, and a fully-worked lesson-ladder example.
