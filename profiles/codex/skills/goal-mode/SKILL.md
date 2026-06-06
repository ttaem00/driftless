---
name: goal-mode
description: >
  goal-mode (Codex 전용): Codex의 대표 모드인 `goal` / GOAL 레인을 운영한다.
  관리자가 명확한 목표 + 성공 기준을 주면 Codex가 더 오래 자율적으로 일한다.
  서로 독립적인(write surface가 겹치지 않는) 티켓들은 각각 별도 worker GOAL
  레인으로 병렬 실행하고, 같은 issue/branch를 두 레인이 동시에 건드리지 않도록
  session-claim 핸드셰이크(쓰기 전 확인, 시작 시 점유)로 경합을 막는다.
  이 모드는 Codex 프로필 전용이다. Claude 프로필의 대응물은 ultracode이며,
  서로 다른 도구의 패러다임이라 강제로 대칭화하지 않는다.
  Use when the manager wants Codex to run a goal with success criteria,
  work autonomously for longer, fan out independent tickets as separate GOAL
  lanes, or needs the session-claim handshake that stops two lanes racing the
  same issue/branch.
  Trigger / 트리거: "goal", "goal mode", "GOAL 레인", "목표 모드",
  "목표 주고 알아서", "성공 기준 주고 길게", "자율 작업", "오래 돌려",
  "독립 티켓 병렬 레인", "session claim", "레인 경합", "race 방지",
  "autonomous goal", "long-running goal".
---
## Improvement Principle

Use root-cause analysis and root-cause fixes, not symptom patches. Generalize as principle-based guidance or design principles; avoid spec/case overfitting and special-casing unless evidence proves a bounded exception reduces user effort, maintainer effort, maintenance risk, or safety burden.
# Goal Mode (Codex)

Codex의 headline 실행 모드다. 관리자는 **무엇을 끝내야 하는가(목표)** 와
**무엇이 보이면 끝난 것인가(성공 기준)** 만 준다. 그러면 Codex 세션이 평소보다
더 오래, 더 자율적으로 그 목표를 향해 일한다 -- 단계별로 관리자에게 다시 물어보지
않고, 막히면 스스로 bounded 시도를 거치며, 진짜 관리자 결정만 위로 올린다.

> 핵심 프레이밍: 이것은 "할 일 목록"을 받는 모드가 아니라 "도달 상태"를 받는
> 모드다. 목표 + 성공 기준이 명확할수록 Codex가 더 멀리 자율로 간다. 기준이
> 모호하면 길게 도는 것이 위험해지므로, 먼저 성공 기준을 구체화한다.

## Claude ultracode와의 대비 (짧게)

같은 본질 목표(시간/토큰/관리자 개입을 줄이며 일을 끝까지 미는 것)를 두 도구가
서로 다른 패러다임으로 푼다.

- **Codex `goal` / GOAL 레인** = 목표 + 성공 기준을 주면 세션이 더 오래 자율로
  일하고, 독립 티켓은 별도 worker GOAL 레인으로 fan-out 한다(레인마다 한 issue).
- **Claude ultracode** = Claude가 자기 subagent를 직접 오케스트레이션해 이 레포
  일을 미는 네이티브 흐름이다.

둘은 도구별 패러다임이라 한쪽을 다른 쪽에 억지로 이식하거나 강제 대칭화하지
않는다. 같은 일을 각자의 모드로 풀 뿐이다. (Codex 프로필은 single-AI-per-profile:
peer/recursive AI 호출이나 다른 CLI 브리지를 active path에서 부르지 않고, GOAL
레인 fan-out도 Codex 자신의 worker 세션 안에서만 이뤄진다.)

## Manager Contract

관리자(비개발자)는 단 한 번만 입력한다:

```text
목표:        <도달해야 하는 상태 한두 문장>
성공 기준:   <보이면 끝난 것으로 인정할 검증 가능한 신호들>
범위/제외:   <건드리지 말 것, 또는 "알아서">
```

그 다음은 Codex GOAL 세션이 소유한다: inventory, 레인 분해, session-claim 점유,
실행, 재시도, 검증/머지/이슈/Project 게이트, 마지막 관리자 보고까지. 관리자에게는
진짜 관리자 결정만 올린다(공유 설계 계약의 manager-only 게이트): 제품/우선순위,
유료 과금, 공개 릴리스, 비가역/파괴적 행동, host-global 변경, credential 입력/사용,
사용자 데이터 이전 위험, force-push, history reset.

> API 크레딧 메모: 이 미러의 Codex goal-mode 절반(PR 리뷰 / 릴리스 자동화 같은
> 더 길게 도는 GOAL 레인)은 해당 프로그램의 API 크레딧으로 자금이 충당된다.
> 길게 도는 자율 작업의 비용 축이 여기에 붙는다는 점을 보고에서 투명하게 드러낸다.

## Goal + Success Criteria (게이트)

길게 자율로 돌기 전에 먼저 다음을 확정한다. 모호하면 자율 길이를 줄이고 기준부터
구체화한다(모호한 기준 + 긴 자율 = 헛돈/헛토큰).

- **목표(도달 상태)**: 한두 문장. "X가 되어 있어야 한다."
- **성공 기준(검증 신호)**: 각 기준은 *검증 가능*해야 한다 -- 통과하는 명령,
  보이는 동작, 머지된 PR, 닫힌 이슈, 재현 테스트 통과 같은 실측 신호. "잘 됐다"
  같은 prose는 기준이 아니다.
- **실패 처리**: 기준이 안 맞으면 어떻게 할지(bounded 재시도 후 보고, 또는
  관리자 질문)를 미리 정한다.

성공 기준은 빈/누락 출력으로 충족되지 않는다. 빈 출력은 PASS가 아니라 UNVERIFIED다.

## GOAL Lane Fan-Out (parallel-safe independent tickets)

서로 독립적인 티켓 -- 즉 **write surface가 겹치지 않고 의미상 선후 의존이 없는**
티켓 -- 만 별도 worker GOAL 레인으로 병렬 실행한다.

- 한 레인 = 하나의 issue/branch. 한 티켓을 조사 -> 구현 -> 검증 -> PR 같은 직렬
  마이크로 레인으로 쪼개지 않는다.
- 같은 파일/스키마/계약/락파일/생성물/issue 소유권을 건드리는 티켓은 병렬이
  아니라 **직렬화**하거나 통합 레인으로 합친다.
- 각 레인에 `owner`(쓰기 가능) / `read-only`(참조) / `forbidden`(금지) surface를
  명시한다. 레인은 자기 owner surface 밖으로 나가면 즉시 멈춘다.
- 새 파일을 *생성*하는 레인은 격리 worktree가 아니라 main 체크아웃에서 처리해
  새 파일이 수집되지 않고 소실되는 것을 막는다. 격리 패치 레인만 워크트리를 쓴다.
- fan-out은 Codex 자신의 worker GOAL 세션이 한다. 외부 에이전트/peer/MoA/다른
  CLI 브리지를 부르지 않는다.

## Session-Claim Handshake (두 레인이 같은 issue/branch를 경합하지 않게)

병렬 GOAL 레인의 핵심 안전장치다. **쓰기 전에 확인하고(check before mutate),
시작할 때 점유한다(acquire on start).**

순서:

1. **Check (쓰기 전 확인)**: 레인이 어떤 issue/branch를 mutate 하기 전에, 그
   issue/branch에 대한 활성 claim이 이미 있는지 먼저 확인한다. claim 신호는
   가벼운 레포-로컬 마커(예: GOAL 런 디렉터리 아래의 claim 파일)와 라이브 GitHub
   상태(같은 issue를 들고 있는 다른 열린 branch/PR)를 같이 본다.
2. **Acquire (시작 시 점유)**: claim이 비어 있으면, 레인은 시작과 동시에 자기
   레인 id / issue 번호 / branch / 타임스탬프를 담은 claim을 기록해 점유한다.
   이때부터 그 issue/branch는 이 레인 소유다.
3. **Conflict (이미 점유됨)**: claim이 이미 있으면 그 레인을 병렬로 띄우지
   않는다 -- 점유 해제까지 직렬 대기하거나, 다른 독립 레인으로 재배치하거나,
   통합 레인으로 합친다. 두 레인이 같은 branch를 동시에 쓰는 일은 금지다.
4. **Release (해제)**: 레인이 끝나거나(adopt/merge/close) 안전하게 중단되면
   claim을 해제한다. 해제된 claim 때문에 직렬 대기하던 레인은 그 시점에
   runnable-now로 재분류된다(claim이 풀렸는데 done 밑에 닫아두면 안 된다).

claim은 점유 의도의 신호일 뿐, 강제 잠금이 아니다. 그래서 mutate 직전 재확인이
load-bearing 하다: stale 한 오래된 claim 하나로 "이 레인은 시도했다"가 성립하지
않으며, 점유 확인 없는 병렬 fan-out은 같은 branch race로 작업 소실을 부른다.

## Autonomous Blocker Resolution (막혀도 바로 미루지 않는다)

GOAL 레인이 "개선 필요 / 최신 조사 필요 / 통합 필요 / 검증 실패 / 데이터 부족 /
watch / 후속 / 보류"로 끝나려 하면, 미루기 전에 그 남은 일이 agent-solvable 인지
먼저 분류한다.

- **Agent-solvable**: 같은 GOAL 세션에서 bounded 시도를 한다 -- 로컬 명령, 테스트,
  코드 수정, 브라우저 자동화, 공개 인터넷/최신 문서 확인, 오픈소스/도구 도입 검토,
  의존성 probe, 공개 데이터 경로, 레포 도구, 안전한 로컬 산출물 생성. 시도한 방법,
  출력, 한계, 남은 옵션이 왜 안전하지 않거나 불가능한지, 다음 재시도 조건을 기록한다.
- **Manager-only**: manager-only 게이트만 관리자에게 짧은 질문으로 올린다.
- **Hard-external**: 의존성이 실제로 불가능/유료/계정 필요임을 증명하는 정확한
  명령/소스 증거를 남긴다.

열린 이슈, 코멘트만 단 상태, "나중에 하자"는 표현은 agent-solvable 한 일이 남아
있는 한 Done이나 소진(exhaustion)의 근거가 되지 못한다. "관리자가 결정할 것 없음"을
agent-solvable 작업이 열려 있는 채로 말하지 않는다 -- 대신 "관리자 행동: 없음;
Codex 행동: 이 GOAL 계속" + 정확한 다음 runnable 레인을 적는다.

## Done-State 모순 / Future-Flow Escape 가드

GOAL 런이 PR을 머지하고도 agent 소유 작업을 `status: done` 뒤에 숨길 수 있다.
레인 버킷을 prose가 아니라 *필드*(레인 상태/카운트)로 확인한다.

- **Done-State 모순**: done 상태인데 남은 agent-소유 레인 버킷(blocked /
  serialized_wait / claim_released_ready / not_started / failed / review_ready)이
  0보다 크면, 각 레인이 manager-only / hard-external / serialized-dependency 로
  분류된 current-run 소진 기록으로 덮이지 않는 한 무효다. 빈 `blockers: []` 만으로는
  부족하고, agent-solvable 소진 기록은 덮개가 되지 못한다.
- **Future-Flow Escape**: current-run inventory / 우선순위 핵심 이슈 /
  claim 해제된 레인 / 데이터 획득 레인을 "다음 티켓 흐름 / 다음 GOAL 런 / 후속 /
  보류 / 나중"으로 미루면, manager-only 결정 / 검증된 hard-external 블로커 / 런
  전에 승인된 범위 경계 / 명령 증거로 소진된 bounded 시도 / 열린 not-Done 추적기 +
  정확한 다음 재시도 조건 중 하나를 증명하지 않는 한 FAIL이다.
- **Claim-released 재분류**: claim 때문에 직렬화됐던 레인이 claim 해제로
  runnable 해지면 더 이상 serialized가 아니다 -- runnable-now(또는
  manager-only/hard-external)로 재분류한다. current-run 시도 없이 done 밑에
  닫아둘 수 없다.

## Final Output

GOAL 세션의 마지막 응답에는 다음이 포함된다:

1. 생성/변경 파일 경로
2. 관리자용 요약 한 단락(쉬운 한국어, 네 가지 manager label 중 하나로 시작,
   증거 라인은 그 뒤에)
3. 레인별 실행 상태 + 증거 경로 + 각 레인의 session-claim 상태(점유/해제)
4. 남은 UNVERIFIED / BLOCKED 증거 + 열린 not-Done 추적기
5. self-check 결과

## Self-Check

- [ ] 목표 + 검증 가능한 성공 기준이 확정됐다(모호하면 자율 길이 축소 + 기준 구체화).
- [ ] 병렬 GOAL 레인은 write surface가 disjoint 하고 의미 의존이 없다; 같은
  파일/계약/issue 소유권을 건드리는 레인은 직렬화/통합됐다.
- [ ] 각 레인 = 하나의 issue/branch; 한 티켓을 직렬 마이크로 레인으로 쪼개지 않았다.
- [ ] session-claim 핸드셰이크 적용: 쓰기 전 확인, 시작 시 점유, 충돌 시 직렬/재배치,
  종료 시 해제, mutate 직전 재확인(stale claim 단독으로 "시도함" 성립 금지).
- [ ] 두 레인이 같은 branch를 동시에 쓰지 않는다.
- [ ] 새 파일 생성 레인은 main 체크아웃에서, 격리 패치 레인만 워크트리에서 처리한다.
- [ ] fan-out은 Codex 자신의 worker GOAL 세션 안에서만; peer/recursive AI,
  MoA, 다른 CLI 브리지를 active path에서 부르지 않는다(single-AI-per-profile).
- [ ] agent-solvable 미완은 bounded 시도 없이 미루지 않았다.
- [ ] Done-State 모순 / Future-Flow Escape를 필드 기준으로 점검했다.
- [ ] claim 해제된 레인은 runnable-now로 재분류됐다.
- [ ] secrets, 환경 비밀 파일, credentials, browser profiles, SSH, auth state,
  host-global agent 프로필은 읽거나 쓰지 않았다(포함은 prose로만 기술).
- [ ] 빈/누락 출력은 PASS가 아니라 UNVERIFIED로 처리했다.
- [ ] 관리자 보고는 쉬운 한국어, manager label로 시작하고 증거 라인을 뒤에 둔다.
- [ ] 길게 도는 GOAL 레인(PR 리뷰 / 릴리스 자동화)의 API 크레딧 비용 축을
  보고에서 투명하게 드러냈다.
