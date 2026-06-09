# Development-runtime PRs (redacted evidence)

This is the **censored photograph** of the real self-built work the
"built itself" numbers refer to. The development runtime that Driftless was
extracted from is **private** (it holds containment-sensitive state, so
publishing it would break the very isolation guarantee Driftless sells). What
we *can* publish, safely, is the metadata: every merged pull request's number,
merge date, and title. No diffs, no secrets, no paths, no account data.

It is metadata-only on purpose. A reviewer cannot click into the private graph,
but can read what the loop actually did, at what cadence, across what kinds of
work. For the part you *can* click and verify with zero trust, see this public
repo's own self-maintaining graph (linked from [loop-log.md](./loop-log.md)).

## Summary

- **113 merged pull requests**, all driven by the overnight autonomous loop under a human maintainer.
- Date range: **2026-05-30 to 2026-05-31** (a focused, high-cadence build).
- By type: 49 feat, 21 fix, 41 docs, 1 chore, 1 other.
- Each PR was ticketed before it was edited (issue-before-edit), ran the safety
  gates, and merged only when green. Risk/permission/release/destructive
  decisions were escalated to the human maintainer, never auto-decided.

## All merged PRs (number | date | title, redacted)

| # | merged | title |
|---|---|---|
| 8 | 2026-05-30 | docs: record bootstrap in ticket workflow (Project 10 + registered tickets) |
| 10 | 2026-05-29 | fix(launcher): restore terminal state on abnormal Claude exit |
| 14 | 2026-05-30 | feat(app): scaffold ultracode GUI app (Tauri v2 + React 19 + Rust) |
| 16 | 2026-05-30 | docs: evidence-honesty completion gate + drop moa-desktop "proven" overclaim |
| 18 | 2026-05-30 | feat(skill): ui-ux-design-guidance auto-trigger skill (profile template) |
| 21 | 2026-05-30 | Windows text-safety gate + catalog for the recurring shell/path failure class |
| 23 | 2026-05-30 | feat(skill): overnight-autonomous-work parent orchestration skill |
| 43 | 2026-05-30 | docs: align hot docs + shared contract + machine files to canonical model |
| 44 | 2026-05-30 | docs: dedup hot CLAUDE.md instructions, route shared enums to canonical sources |
| 45 | 2026-05-30 | fix(containment): tighten claude/codex refRegex (#12) + block Deep Lake host-global store/endpoints |
| 46 | 2026-05-30 | feat(scripts): five GitHub/PR helper scripts for the documented gate logic |
| 47 | 2026-05-30 | docs: rename docs/design.md/DESGIN.md -> docs/design/DESIGN.md + update all refs |
| 48 | 2026-05-30 | feat(shared): establish in-repo shared tier + single-source consumption proof |
| 50 | 2026-05-30 | feat(codex-profile): in-repo codex profile skeleton + shared-tier consumption |
| 51 | 2026-05-30 | feat(learning): tool-separated learning ledger (shared/claude/codex) |
| 52 | 2026-05-30 | feat(cost): token/context ROI runaway control + >1KB-output guard |
| 53 | 2026-05-30 | feat(scripts): hot-context safety audit + lean-gradient discipline gates |
| 54 | 2026-05-30 | docs: wire hot CLAUDE.md + contract to Wave-3 deliverables (#34 #37 #38) |
| 60 | 2026-05-30 | feat(profile): Korean slash-command aliases + advisory skill-router hook |
| 61 | 2026-05-30 | feat(telemetry): SHARED runtime telemetry capture — schema + writer + sink |
| 62 | 2026-05-30 | feat(usage): offline self-contained local usage/cost dashboard |
| 63 | 2026-05-30 | feat(pilot): local session-summary generator scaffold — build-only, dry-run |
| 64 | 2026-05-30 | docs(learning): record claude-tier lesson — duplicate check + ticket skill (#34 first use) |
| 65 | 2026-05-30 | feat(gate): wire rule-integrity checks into PR validation (auto on every PR) |
| 70 | 2026-05-30 | docs: committed manager-decisions log + README link |
| 71 | 2026-05-30 | docs: decision register with decider attribution (Manager/Claude/Codex), shared tier |
| 72 | 2026-05-30 | chore: remove leaked adversarial-test scratch file from docs/ |
| 74 | 2026-05-30 | docs(learning): cleanup-hook + workflow-isolation lessons; mark D4a redesign |
| 75 | 2026-05-30 | docs(decisions): D8 token-frugal verification rule (adversarial review = 1, not 4) |
| 76 | 2026-05-30 | docs(#55): complete PDR-CONTEXT-ROOT-CAUSE-CHECK |
| 77 | 2026-05-30 | docs(#56): complete PDR-BLOCKER-AUTOFOLLOWUP |
| 78 | 2026-05-30 | docs(#57): add One-Click Default rule to MANAGER_OPERATING_MODEL |
| 79 | 2026-05-30 | docs(#58): complete dependency-incident audit playbook |
| 80 | 2026-05-30 | docs(#42): align 4 out-of-#41-scope files to canonical model |
| 81 | 2026-05-30 | fix(#66): reframe cost to subscription usage, not USD |
| 82 | 2026-05-30 | feat(#6): Sync-SharedContract.ps1 in-repo drift checker |
| 83 | 2026-05-30 | feat(#28): non-blocking offline SessionStart skill-sync hook |
| 84 | 2026-05-30 | feat(#73): safe disposable-doc cleanup (adversarial-passed redesign) |
| 85 | 2026-05-30 | feat(#67): port 7 codex ticket/ops skills + auto-trigger router |
| 86 | 2026-05-30 | docs(#69): tool divergence analysis + adoption verdicts |
| 87 | 2026-05-30 | docs(#68): automation audit + wire drift checker into gate |
| 88 | 2026-05-30 | docs(decisions): record overnight agent decisions A6-A8 |
| 89 | 2026-05-30 | fix(#19): auto-preflight at launch + launcher-only README warning |
| 91 | 2026-05-30 | docs(decisions): A9 Haiku-subagent-is-subscription correction (#29 unblock) |
| 92 | 2026-05-30 | feat(#67): FULL codex skill port (44 covered, 0 residual) + hooks + dynamic router + coverage guard |
| 94 | 2026-05-30 | feat(#67): hooks coverage + classify all 244 scripts + extend coverage guard |
| 95 | 2026-05-30 | docs(decisions): A10 completeness-gate for full-port |
| 96 | 2026-05-30 | feat: gate against reintroducing Get-FileHash (PowerShell 7-fragile cmdlet guard) |
| 98 | 2026-05-30 | feat(#97): 오버나이트 '끝까지 해결' 구조적 강제 (Exhaustion Ledger 게이트) |
| 100 | 2026-05-30 | fix(#99): 8개 agent-solvable 카테고리 전부 커버 + 구조적 강제 (#97 후속) |
| 102 | 2026-05-30 | docs: empty-tool-output=UNVERIFIED gate + rtk adoption eval (pending manager) |
| 109 | 2026-05-30 | feat(#103): adopt rtk into claude profile -- settings deny + RTK.md (codex-canonical) |
| 110 | 2026-05-30 | fix(#105): preserve projects/ (user memory) across -ResetProfile (data-loss bug) |
| 111 | 2026-05-30 | feat(#107): pin rtk to v0.42.0 + reject rtk's wrap-everything default in RTK.md |
| 112 | 2026-05-30 | docs(#108): D11 -- cancel RTK peer infra adoption (manager rejected) |
| 113 | 2026-05-30 | docs(D12): peer/MoA rejected by default -- do not even ticket it |
| 114 | 2026-05-30 | docs(#3): resolve ULTRACODE CLI controls (xhigh/orchestration/1M/credits PASS) |
| 115 | 2026-05-30 | fix(#13): make app/ultracode scaffold build + verify npm/cargo PASS |
| 116 | 2026-05-30 | feat(#90): ROI measurement loop discipline (5-axis keep/kill/watch) |
| 117 | 2026-05-30 | feat(#93): port 5 of 12 SHOULD_PORT codex ops scripts (root-goal-checked) |
| 118 | 2026-05-30 | feat(#49/#40): re-author 10 codex-profile ops skill bodies (peer/MoA excluded) |
| 119 | 2026-05-30 | feat(#40): codex profile launcher (materializes codex-home, verified -NoLaunch) |
| 121 | 2026-05-30 | feat(#2/#120): ultracode GUI P0+P1 — Rust 백엔드 + React 프론트엔드 + 테스트 (cargo 37 / vitest 22 / 게이트 PASS) |
| 123 | 2026-05-31 | fix(#122): ultracode GUI UIUX 감사 수정 — focus-visible + error 회복 CTA + reduced-motion (DESIGN.md) |
| 124 | 2026-05-31 | feat(#90/#29/#30): first MEASURED ROI verdicts -- skillify KILL, autosummary ADOPT |
| 127 | 2026-05-31 | docs(D14/A13/A14): skillopt+ML is core -- root-cause for #29 KILL + prevention + EPIC #125 |
| 128 | 2026-05-31 | docs: lesson promotion ladder + stop dev-only codex rule shipping in product skill |
| 130 | 2026-05-31 | feat(#126): skillopt Phase 0 -- LLM-zero validation harness + schemas + ranking |
| 132 | 2026-05-31 | fix(#129): stop this-repo/machine hardcoding shipping to product + structural gate |
| 134 | 2026-05-31 | docs(A16): audit porting misjudgments -- correct #93 skillopt EXCLUDE + handoff gap #133 |
| 136 | 2026-05-31 | feat(#135): codex-precedence gate -- structured reject/exclude must show it checked codex (dev-only) |
| 138 | 2026-05-31 | feat(A17): port codex Final Artifact-to-Claim Audit into overnight-all-tickets skill |
| 139 | 2026-05-31 | feat(#137): mechanical final-artifact audit validator (both directions proven) |
| 140 | 2026-05-31 | feat(#131): skillopt Phase 1 -- easy-briefing harness-validated (live deferred-pending-real-use) |
| 141 | 2026-05-31 | docs(A18/#133): handoff eval -- DEFER-with-trigger (duplicate of #30) |
| 142 | 2026-05-31 | fix(A19): parallel new-file lanes isolate by disjoint paths, not worktrees |
| 144 | 2026-05-31 | feat(A20): port codex Same-Run Attempt Ledger Gate into both overnight skills |
| 145 | 2026-05-31 | fix(#143): gates robust to git line-ending warnings + block-comment mentions |
| 147 | 2026-05-31 | docs(#146): tool-output discipline hot rule (malformed call + empty-output recovery) |
| 149 | 2026-05-31 | fix(#148): hot-context SIZE budget gate (prevent CLAUDE.md silent bloat) |
| 154 | 2026-05-31 | fix(#153): wire hot-context size budget check FOR REAL (#148 left it unwired) |
| 155 | 2026-05-31 | feat(#152): optimization radar detector + ranked report + fixtures (#151 Phase 1) |
| 159 | 2026-05-31 | fix: 3 tool-composition gap tickets (#156 parallel-Workflow boundary, #157 reflection ledger, #158 overnight conflict) |
| 160 | 2026-05-31 | docs: manager decision D6 (#40 build approved + #131/#150 self-generate-data) |
| 161 | 2026-05-31 | feat(#40): codex profile preflight/doctor + launcher wiring (D6 build) |
| 162 | 2026-05-31 | docs(#150): measured 5-axis ROI loop end-to-end evidence (D6) |
| 163 | 2026-05-31 | docs: record D6 execution A21 (#40+#150 merged, #131 deferred) |
| 165 | 2026-05-31 | fix(#164): 메인 루프 거대 병렬 Bash runaway 가드 (CLAUDE.md #146 + 스킬 3종) |
| 166 | 2026-05-31 | feat(#131): adopt easy-briefing skillopt candidate into the live skill (D6) |
| 167 | 2026-05-31 | docs: A21 correction -- #131 done same session (all 3 D6 lanes complete) |
| 171 | 2026-05-31 | feat(#168): 프로필 미러-패리티 게이트 (공통 스킬 한쪽만 고치면 PR FAIL) |
| 173 | 2026-05-31 | feat(#170): expand optimization radar to all 5 manager axes + profile-mirror signal |
| 176 | 2026-05-31 | docs(#169): codex 병렬-Bash 가드는 의도된 명시적 비대칭 (allowlist 사유 기록, PR #172 재적용) |
| 177 | 2026-05-31 | docs: A22 -- #168/#169/#170 머지 + 정리 + 갭티켓 #174/#175 (경사하강 검증) |
| 178 | 2026-05-31 | docs: 매니저 결정 D7 (#174 우선 / 라다 롤링이슈만 / Phase4 보류) |
| 180 | 2026-05-31 | feat(#174): optimization radar rolling-issue surfacer + Stop auto-trigger (D7 Phase 3) |
| 181 | 2026-05-31 | feat(#175): enforce tool-separated learning-ledger separation as a PR gate (#34 follow-up) |
| 185 | 2026-05-31 | fix(#182): move codex web_search under [tools] so config.load=ok (profile runnable) |
| 186 | 2026-05-31 | feat(#183): add agents/openai.yaml registration manifest to all 10 codex skills (parent #40) |
| 187 | 2026-05-31 | fix(#184): harden codex preflight to codex's REAL config.load (not static TOML parse) |
| 188 | 2026-05-31 | docs: A23 -- #174/#175 머지 + 코덱스 프로필 config-load OK까지 (실 codex CLI 검증) |
| 189 | 2026-05-31 | docs: A23 후속 -- 코덱스 프로필 RUN_READY_VERIFIED (매니저 로그인 후 실작동 검증) |
| 191 | 2026-05-31 | feat(#190): codex profile skill parity (10 -> 34) -- 22 shared + browser/webwright, MoA/peer excluded |
| 192 | 2026-05-31 | docs: A24 -- 코덱스 프로필 스킬 외부 동등화 (10->34, #190 머지) |
| 194 | 2026-05-31 | feat(#193/#40/#32): codex profile hooks parity (6 shared-body hooks, compressed delegators) |
| 195 | 2026-05-31 | docs: A25 -- 코덱스 프로필 훅 동등화 (0->6, 압축, #193 머지) |
| 200 | 2026-05-31 | feat(#197): 격리 Claude/Codex 실행 + 바로가기 쉽게 만들기 내장 기능 (메뉴 런처 + 폴더 피커 생성기) |
| 201 | 2026-05-31 | feat(#198): overnight lane-count Done-State Contradiction + Future-Flow Escape gate (codex+claude parity) |
| 202 | 2026-05-31 | feat(#196): auto-load chrome-devtools MCP + Webwright plugin on both profiles |
| 205 | 2026-05-31 | fix(#204): learning-loop -- gh --json merged 무효필드 + 병렬Bash 에러 연쇄취소 재발방지 |
| 206 | 2026-05-31 | fix(#203): 우클릭-PowerShell 실행 시 바로가기 미생성처럼 보이는 결함 수정 (친절 .bat + 인터랙티브 흐름) |
| 208 | 2026-05-31 | fix(#203): containment FAIL on main -- installer docstring named host-global paths |
| 209 | 2026-05-31 | fix(#207): containment guard own-path exemption for repo-local .claude/.codex |

## Redaction note

Only public-safe metadata is published here: PR number, merge date, and a
title with any trailing internal issue reference stripped. No code diffs,
credentials, file paths, host-global config, `.runtime/` content, or account
data are included. The development repository itself remains private by
design — keeping it private is part of the containment guarantee, not a
limitation we are hiding.
