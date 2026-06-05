---
name: adopt-external-tool
description: >
  외부도구안전도입 adopt-external-tool: 사용자나 에이전트가 외부 GitHub 레포,
  오픈소스 도구, 스킬/프롬프트 자산, MCP 서버, 라이브러리를 이 프로필에 "적용"하기
  전에 따르는 작은 안전 체크리스트. 코드/아키텍처를 통째로 복사하지 않고, 비밀정보·
  호스트 전역·되돌릴 수 없는 일·돈/크레딧·재귀 AI 호출을 들여오지 않도록 한 화면
  분량으로 점검한 뒤 도입/파일럿/보류/거부 중 하나로 닫는다. 실제 설치(MCP/의존성/
  플러그인)는 반드시 먼저 묻고 기본값은 "아니오".
  Use BEFORE applying any external repo, open-source tool, third-party skill or
  prompt asset, MCP server, or library to this profile. A one-screen safety vet
  echoing the "scan before you trust" idea, kept lean: no new dependency, no
  scanner install -- a checklist the agent runs, then closes with a verdict.
  Trigger / 트리거: "이 도구 도입", "이 레포 적용해도 돼", "외부 스킬 가져와",
  "MCP 추가해", "이거 설치해줘", "오픈소스 도입 검토", "adopt this tool",
  "apply this repo's skill", "add this MCP", "is this safe to install",
  "vet this repo", "should I install this".
---

# Adopt an external tool safely (외부 도구 안전 도입 체크리스트)

이 스킬은 외부 자산(레포 / 도구 / 스킬 / 프롬프트 / MCP 서버 / 라이브러리)을
**이 프로필에 적용하기 전에** 에이전트가 스스로 돌리는 한 화면 분량의 안전 점검이다.
목표는 "scan before you trust" -- 신뢰하기 전에 먼저 본다. 새 스캐너를 설치하지
않고(의존성 0), 에이전트가 체크리스트를 직접 확인한 뒤 한 가지 판정으로 닫는다.

> 코드/아키텍처를 통째로 복사하지 않는다. 아이디어를 이 프로필에 맞게 **변형**해서
> 가장 작은 형태로만 들여온다. "전부 이식"이 아니라 "한 가지 쓸모 + 가장 작은 형태".

## 절대 규칙 (load-bearing)
- **설치는 먼저 묻고 기본값은 "아니오".** MCP 서버 / 의존성 / 플러그인 / 새 패키지를
  사용자에게 설치하기 전에, 무엇을·왜 설치하는지 평이하게 설명하고 동의를 받는다.
- **호스트 전역을 건드리지 않는다.** 외부 자산이 `~/.claude` / `~/.codex` / 사용자
  홈 / OS 전역 설정을 읽거나 쓰라고 하면 거부하거나, 격리 홈(이 레포 안) 안에서만
  돌도록 변형한다.
- **비밀·돈·재귀를 들여오지 않는다.** API 키 요구, 유료/과금 호출, 클라우드 캡처,
  피어/재귀 AI 호출(다른 에이전트를 띄우는 래퍼)은 기본 거부. 들이려면 사용자 결정.
- **확인 못 한 건 "안전하다"고 하지 않는다.** 메타데이터(스타·라이선스·마지막 커밋·
  보안정책)를 실제로 보지 않았으면 `UNVERIFIED`로 적는다. 추측으로 PASS 금지.

## 7가지 점검 (한 줄씩, 순서대로)
각 항목을 PASS / FAIL / UNVERIFIED 로 적는다. 하나라도 FAIL이면 그대로 도입하지 않는다.

1. **라이선스가 공개-안전한가.** MIT/Apache 등 재배포 가능한 라이선스인가, 아니면
   불명/제한적인가. (불명 = UNVERIFIED, 비호환 = FAIL)
2. **새 인프라/유료/네트워크를 끌어오는가.** DB·서버·클라우드·과금 API·항상 켜진
   프로세스가 필요한가. (필요 = LEAN 위반 후보 -> 보통 보류 또는 파일럿)
3. **호스트 전역이나 비밀 경로를 만지는가.** `~/.claude`/`~/.codex`/`.env`/`.ssh`/
   브라우저 프로필/`secrets/`/개인키를 읽거나 쓰는가. (그렇다 = FAIL, 격리 변형 필요)
4. **인라인 비밀이 들어 있는가.** 코드/설정에 키·토큰·PRIVATE KEY 블록이 박혀
   있는가. (그렇다 = FAIL, 절대 커밋 금지)
5. **피어/재귀 AI를 띄우는가.** 다른 에이전트/CLI/MCP 브리지를 스폰하는 래퍼인가.
   (그렇다 = 기본 거부; 도구/정책만 떼어내고 래퍼는 버린다)
6. **이 프로필에 정말 필요한가 (ROI).** 5축(토큰/개입/시간/돈/성능) 중 무엇을 줄이는
   가. 기존 스킬/게이트가 이미 더 싸게 해결하지 않는가. (이미 해결됨 = 도입 안 함)
7. **가장 작은 형태가 무엇인가.** 통째 도입 말고, 같은 쓸모를 주는 가장 작은 조각
   (문서 한 줄 / 체크리스트 한 개 / 작은 스크립트 한 개)으로 줄일 수 있는가.

## Adoption Surface Ledger

For broad systems, do not decide only `install vs reject`. Split the candidate
into surfaces and close each useful surface as adopted, scaled to an owned
issue, watched, rejected, blocked, or manager-only. `piloted` is evidence, not a
final closeout state.

Common surfaces:

- architecture pattern
- script or CLI shape
- GUI/dashboard/status UX
- credential/security boundary
- multi-worker/process model
- fixture or benchmark method
- docs/skill template
- runtime dependency
- public-safe propagation

Full-system rejection is valid only after viable surfaces have their own
closeout. Risk is not a rejection by itself; if value is plausible, design the
smallest contained pilot that avoids credentials, billing, host-global mutation,
public release, destructive action, user data, or long-running infrastructure.

For large agent harness, orchestration, skill-pack, IDE-agent, MCP/plugin, or
automation-control repos, inspect the whole operational surface before deciding:
hooks, scripts, skills, rules, commands/prompts, multi-agent/workflow control,
dashboard/status UI, credential/API/security boundary, architecture, code-level
reusable patterns, feature ideas, new technology/libraries, test/fixture
strategy, and development process. Do not stop at README/package metadata or one
safe subset; transform useful surfaces into local-safe gates, schemas, skills,
UI status, docs, or fixture pilots.

## Post-Pilot Decision Gate

PILOT_ONLY is not Done when the pilot merely ran. Before Done, record the
decision the pilot answered:

- adopt the bounded surface now;
- scale it to an owned issue or PR;
- watch it with a concrete retry trigger;
- reject it with measured evidence and a retry condition;
- block it on an exact external or manager-only condition.

Do not report a fixture, mock, benchmark, dry-run, read-only audit, or
`piloted` surface as complete without that post-pilot decision.

## 판정 (하나로 닫기)
- **ADOPT_SMALL** -- 7항목 통과 + 가장 작은 형태로 변형 가능. 작게 변형해 들인다.
- **PILOT_ONLY** -- 쓸모는 있으나 실제 한 흐름에서 먼저 증명해야 함. 성공/실패 기준을
  적고 한 번 돌려본다. 파일럿 후에는 ADOPT_SMALL / owned follow-up /
  WATCH_LATER / REJECT / blocked(manager-only) 중 하나로 다시 닫는다.
- **WATCH_LATER** -- 좋은 아이디어지만 지금은 크기/시점이 안 맞음. **재평가 트리거**를
  한 줄로 적는다(예: "UI 작업이 들어오면").
- **REJECT** -- 경계 위반(인프라/유료/재귀/containment) 또는 ROI 없음. 사유를 적는다.
  **"무거워 보인다"는 REJECT 사유가 못 된다.** lean은 "헤비하면 버린다"가 아니라
  "작게 pilot 한다"이다. 무거운 후보일수록 먼저 6/7항목으로 가장 작은 형태(지식그래프
  -> 레포 구조 1장 요약 파일, 통합상태 DB -> 기존 issue/PR/evidence를 읽는 작은 인덱스)를
  설계해 PILOT_ONLY로 돌려보고, 5축 이득이 측정으로 없을 때만 REJECT한다. pilot을
  건너뛰고 인상만으로 REJECT하는 것은 회피다.
- **UNVERIFIED** -- 라이선스/메타데이터/동작을 실제로 못 봤다. 무엇을 못 봤는지 적고,
  실제 확인 전에는 도입하지 않는다.

판정은 `docs/external-repo-review.md`에 한 항목으로 추가한다(짧게, 위 라벨 + 한두 줄
사유 + 재평가 트리거). 같은 레포를 다음에 또 보지 않게 기록을 남긴다.

## 검증 (도입했다면, 추측 금지)
도입을 실제로 했다면 안전 게이트를 돌려 증거를 남긴다:
- 컨테인먼트: `scripts/Test-Containment.ps1` (호스트 전역/비밀 미접촉 증명)
- 미러 패리티: `scripts/Test-ProfileMirrorParity.ps1` (공유 자산이면 양쪽 동시 갱신)
- 윈도우 텍스트 안전: `.ps1/.bat/.cmd`를 추가/수정했으면 `scripts/Test-WindowsTextSafety.ps1`
게이트를 못 돌렸으면 "됐다" 대신 `UNVERIFIED`로 보고한다.

## 안 하는 것
- 코드/아키텍처 통째 복사 · 묻지 않은 설치 · 호스트 전역 수정 · 비밀/키 취급 ·
  유료/과금 호출 · 피어/재귀 AI 스폰 · 라이선스 미확인 채 재배포. 전부 사용자 결정으로
  돌리거나 거부한다.
