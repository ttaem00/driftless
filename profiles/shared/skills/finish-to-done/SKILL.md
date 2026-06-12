---
name: finish-to-done
description: >
  Use when the manager asks to finish a task to completion, fix the root cause so
  it does not recur, or carry work all the way to PR_READY/verified -- 끝까지 /
  근본 원인 / 재발 안 되게 / 검증까지 끝내달라고 할 때. (끝까지해결 finish-to-done)
  조사 -> 수정 -> 검증 -> 리뷰 -> 완료 신호까지 증거 기반으로
  끝까지 진행한다. 조사만 하고 멈추지 않는다. agent-solvable blocker는 같은 세션에서
  근본원인 follow-up을 만들고 원 게이트를 재시도해 해결한다.
  Trigger / 트리거: "끝까지", "끝까지해결", "근본 원인", "재발 안 되게", "PR_READY까지",
  "검증까지", "merge 후 pull", "티켓 완료", "finish to done".
---
## Improvement Principle

Use root-cause analysis and root-cause fixes, not symptom patches. Generalize as principle-based guidance or design principles; avoid spec/case overfitting and special-casing unless evidence proves a bounded exception reduces user effort, maintainer effort, maintenance risk, or safety burden.
# Finish To Done

`끝까지해결`: 요청한 작업을 완료선까지 증거 기반으로 진행한다. 조사하고 멈추거나,
문제를 기록만 하고 손을 떼지 않는다. 이 스킬은 어떤 에이전트 프로필에서도 동일하게
동작하는 공유 스킬이다. 티켓 발행 스킬, blocker-autofollowup 절차와 함께 쓴다.

## 한글 호출 예시
- `끝까지해결로 이 티켓 PR_READY까지 밀어줘.`
- `근본 원인 찾고 재발 안 되게 고친 뒤 검증까지 해줘.`

## Completion Lines (보고서의 마지막 줄)
보고서는 반드시 아래 한 줄로 끝난다:
- `MERGED_DONE`: 병합 + base pull + 보드/트래커 정리 완료.
- `PR_READY`: PR 준비됐고 수동 병합 또는 매니저 승인 대기.
- `BLOCKED_NEEDS_FOLLOWUP`: 근본원인 follow-up 후에도 manager-only / hard-external
  blocker가 남아 open / not-Done 상태이며, 다음 실행 가능한 행동이 명시돼 있음.
- `REVIEW_RUN_ERROR`: 복구를 시도한 뒤에도 리뷰 대상을 못 읽음.
- `CONFLICT_NEEDS_HUMAN`: cleanup 후에도 충돌이 안전하게 해소되지 않음.
- `STOP`: 안전한 follow-up으로 줄일 수 없는 safety stop.

`BLOCKED_NEEDS_FOLLOWUP` / `REVIEW_RUN_ERROR` / `CONFLICT_NEEDS_HUMAN` / `STOP`은
agent-solvable blocker에 대한 첫 반응으로 쓰면 안 된다. 먼저 아래 Autonomous
Blocker Resolution을 돌리고 그 증거를 보고한다.

## PR Check Closeout Loop

PR check states are evidence, not human homework. `WAITING_CHECKS`,
`IN_PROGRESS`, missing check rollups, and failed validation are agent-solvable by
default when the next action is to inspect CI logs, fix a gate, rerun local
validation, poll status, or retry mergeability / auto-merge.

Before any final report:

1. Read the failing or pending PR state with the repo's normal GitHub helper or
   `gh pr view`.
2. If a check failed, inspect CI logs and reproduce locally when the repo has a
   merge-ref reproduction helper.
3. Fix the root cause, not only the latest log line.
4. Rerun the relevant local gate, then poll until checks complete.
5. Retry mergeability and routine auto-merge when the repo supports it.

Stop before this loop only for true manager-only or hard-external blockers.

## Autonomous Blocker Resolution
완료에 도달하지 못한 모든 상태를 다음으로 분류한다:
- **Agent-solvable:** 누락된 테스트, 실패한 검증, dirty checkout, mergeability
  불명, `WAITING_CHECKS`, `IN_PROGRESS`, failed PR validation, missing check
  rollup, 리뷰 실행 오류, 스크립트 버그, 문서 갭, 숨어 있는 사용자-노출
  진입점, UI/UX 배치 갭, 새로 만들거나 재사용할 수 있는 follow-up 이슈.
- **Manager-only:** 제품/우선순위 결정, 자격증명, 결제/쿼터, 공개 배포,
  파괴적·비가역 작업, 사용자 환경 전역으로의 승격, 사용자 데이터 이전, 강제 푸시,
  히스토리 리셋.
- **Hard external:** 사용 불가한 업스트림, 없는 계정 권한, 유료 리소스, 부재한
  사람-자격증명.

Agent-solvable flow: (1) 멈추거나 매니저에게 묻지 않는다. (2) 가장 좁은 근본원인
follow-up 이슈를 만들거나 재사용한다(이슈 트래커 등록은 실제 등록 ID가 돌아올 때만
유효). (3) 같은 세션에서 그 follow-up에 동일한 `finish-to-done`을 돌린다.
(4) 원래 티켓/게이트를 재시도한다. (5) `MERGED_DONE` / `PR_READY`에 도달하거나
manager-only / hard-external만 남을 때까지 반복한다. (6) follow-up이 원 blocker를
해소하지 못하면, 정확한 다음 실행 행동과 함께 open / not-Done으로 둔다.
Manager-only -> 짧은 한국어 질문 하나. Hard external -> 사용 불가한 의존성 +
명령 증거 + 다음 재시도 조건을 정확히 보고.

Worker-assisted `finish-to-done` inherits the same closeout gate. If any worker
was used, Done requires `worker_recovery_inventory`; `MODEL_CAPACITY_RETRY`,
`CONTEXT_ROLLOVER_RETRY`, `PARTIAL_RETRY_REQUIRED`, and agent-solvable `FAILED`
must be retried from compact evidence or left as an explicit not-Done tracker
with a retry condition.

English enforcement anchor: run the root-cause follow-up in the same session,
then retry the original ticket/gate. Completion requires original goal
validation, or a verified manager-only / hard-external blocker with a not-Done
tracker and next retry condition.

## No Substitute Done
구현/증명/병합 티켓은 다음만 한 경우 완료가 아니다: blocker 원인만 기록, 증거 코멘트만
게시, 문서에 한계만 추가, 사용자 기능이 raw URL / 숨은 경로 / 내부 명령으로만 존재,
유망한 실험을 adopt / scale / watch / reject 결정 없이 방치. 완료는 원래 목표에 대한
검증 PASS, 또는 검증된 manager-only / hard-external blocker + open not-Done 트래커 +
다음 재시도 조건을 요구한다. 런타임/사용자-노출 주장에는 fixture / schema / unit /
static 테스트만으로는 검증이 아니다 -- Done에는 실사용 / end-to-end 증거가 필요하다.
단, 이슈가 명시적으로 어떤 동작도 주장하지 않는 경우는 예외. 빈/누락 명령 출력은
PASS가 아니라 UNVERIFIED.

Agent-solvable 항목을 bounded 접근을 먼저 시도하지 않고 미루는 것("최신 리서치
필요", "데이터 부족", "통합 필요" 등)도 substitute-Done이다 -- 그리고 이것이 야간
자율 작업에서 반복적으로 걸렸던 실패다. 해법은 range-of-effort 규칙이다: 네가 할 수
있는 범위 안에서 전부 시도한 뒤에만 열어 둔다(로컬 명령, 코드 변경, 테스트, 최신
기술 리서치, 오픈소스/도구/데이터-허브 도입 검토, 의존성 프로브, 브라우저 자동화,
공개 인터넷 / 공개 데이터 / transcript 경로).

## Exhaustion Ledger (이게 없으면 미루지 않는다)
어떤 실행이 항목을 open / deferred / blocked로 남기면, 그 항목은 Exhaustion Ledger
항목을 함께 남긴다. Agent-solvable 항목의 경우 그 항목에는 `attemptedApproaches`
(>=1) + `limitHit` + `nextRetryCondition`이 필요하다 -- bounded 접근을 한계까지
시도했음을 증명하기 위해서다. 저장소의 finish-to-done discipline 게이트가 이를
강제한다. 야간 자율 작업 스킬이 레저 기록을 책임지고, 이 스킬은 단독 실행 시에도
exhaustion을 기록하도록 규칙을 명시한다.

## Start Checks
워크스페이스 상태를 먼저 확인한다:

```
git status --short --branch
git branch --show-current
git remote -v
```

읽기: 저장소 루트의 에이전트 가이던스 파일, 공유 설계 계약, 매니저 결정 레지스터,
그리고 해당 티켓 / PR / 실패 로그 / 사용자 요구.

## Workflow
1. 완료선을 한 문장으로 재정의.
2. 근본 원인 먼저. 증상만 덮기 금지.
3. 재발 경로를 확인한다.
4. 가장 좁은 책임 경계에서 수정한다.
5. blocker는 위 Autonomous Blocker Resolution으로 처리하고, 같은 세션에서 원
   게이트를 재시도한다.
6. No Substitute Done 적용.
7. 재발 방지 테스트/검증을 추가한다.
8. 저장소의 PR 검증 게이트를 실행한다. 변경된 셸/스크립트 파일은 텍스트-안전
   게이트(ASCII-safe + BOM 없음)도 통과해야 한다.
9. 위험 작업이면 적대 검증 1명(토큰 절약을 위해 기본 1명, 파괴적 작업만).
10. PR 생성 또는 머지-준비 전: mergeability 점검을 돌려 mergeability + PR 댓글 +
    review thread + 연결된 이슈 댓글까지 확인한다. 대상 저장소 이름은 항상 현재
    저장소에서 동적으로 해석하고 하드코딩하지 않는다. 충돌 / dirty / 미검증 /
    코멘트 후속 필요 상태면 성공으로 선언 금지.
11. routine PR auto-merge: 검증 + mergeability + checks + (필요 시) 적대 검증 통과
    + manager-risk 게이트 없음 -> auto-merge 실행. 성공하면 `MERGED_DONE`.
12. 다른 열린 PR이 있으면 그 상태를 매니저 관점으로 분류한다.
13. 병합 뒤 base pull + 보드/트래커 정리.

Done 직전에는 사용 중인 프로필의 containment 가드가 PASS여야 한다(격리 경계 위반
없음). PR/검증 게이트는 저장소 루트의 공유 단일 소스를 쓴다.

## Manager Report
첫 문장은 쉬운 한국어 요약(매니저 4-라벨 중 하나). 기술 용어는 그 뒤 증거 줄에.
마지막 줄은 위 Completion Line 하나.

## Safety
사용자 변경을 임의로 되돌리지 않는다. PASS / PR_READY / merge / pull / clean state는
명령 증거 없이 말하지 않는다. 같은 blocker가 반복되면 학습 레저에 레슨 후보를
기록한다. 현재 PR 충돌을 `PR_READY` 뒤에 숨기지 않는다. 보안상 큰 사안(비밀키 /
자격증명 / 유료 / 공개 배포 / 데이터 삭제 / 사용자 환경 전역 승격)만 매니저에게
질문한다. 리뷰가 파일을 못 읽었으면 통과가 아니라 `REVIEW_RUN_ERROR`. peer /
recursive AI 호출은 하지 않는다(에이전트가 이 저장소의 자기 작업을 위해 자기
서브에이전트를 오케스트레이션하는 것은 허용).
