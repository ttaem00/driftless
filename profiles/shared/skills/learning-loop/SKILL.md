---
name: learning-loop
description: >
  레슨루프 learning-loop: 반복 문제와 시스템 개선 아이디어를 기록하고, 승인/충족된 것만
  지침 파일 / 스킬 / 스크립트 / 훅 변경으로 승격한다. 조사만 하고 멈추지 않는다 -- 재발
  방지가 암시되면 학습 노트에서 멈추지 말고 가장 좁은 저장소-로컬 수정까지 진행한다.
  Trigger / 트리거: "레슨루프", "반복 문제", "교훈", "배운 점", "레슨 적용", "재발 방지",
  "또 그러네", "같은 실수", "시스템 개선 제안", "learning loop", "lesson", "lessons learned",
  "recurring problem", "system update proposal".
---

# Learning Loop

`레슨루프`: 같은 실패를 두 번 설명하지 않도록, 반복 문제 / 교훈 / 시스템 개선 아이디어를
기록하고, 충족되면 규칙 표면으로 승격한다. 이 스킬은 도구에 종속되지 않는다 -- 어느
에이전트가 작업하든 같은 절차를 따른다. 학습 레저의 구조와 항목 스키마(레슨이 속한 tier를
고정하는 필드 포함)는 저장소의 학습 계약 문서가 정본이다.

## When To Use
- 같은 blocker / error가 다시 난다.
- "반복 문제 / 교훈 / 배운 점 / 레슨 적용 / 재발 방지" 요청.
- instruction / hook / skill / system 개선 아이디어가 나왔다.
- 작업이 쓸만한 프로세스 교훈을 남기고 끝났다.

## 한글 호출 예시
- `레슨루프로 이 반복 실수 기록하고 재발 안 되게 고쳐줘.`
- `같은 에러 또 났어. 교훈 남기고 승격할 거 있으면 해줘.`

## Tier 분류 먼저 (어느 레저인가)
레슨은 정확히 한 tier에 속한다(항목의 tier 필드로 고정). 기록 전에 분류한다:
- **shared tier:** 어떤 도구가 작업해도 **동일하게** 재발하는 실수 -- 격리 경계(containment),
  Windows 텍스트 안전, evidence honesty. 승격은 공유 규칙(공유 설계 계약 / shared tier)으로.
- **도구별 tier:** 특정 에이전트 **고유 메커니즘**에서만 나는 실수 -- 그 도구의 설정/홈
  경로, 런처, 훅, 그 도구의 스킬. 승격은 그 도구의 규칙(그 도구의 지침 파일 또는 스킬)으로만.
  shared 표면으로 절대 직행하지 않는다. 한 도구의 레저는 그 도구 프로필이 자기 경로로
  채우고, 다른 도구는 채우지 않는다.

도구별 tier 레슨이 다른 도구에서도 동일하게 재발하면 먼저 tier를 **shared로 재분류**한 뒤
shared 규칙으로 승격한다. 분류 판단은 "다른 도구가 같은 작업을 해도 동일하게 재발하나?"
한 문장으로 한다(아니오 -> 도구별 tier, 예 -> shared tier).

## Storage (source of record)
- **정본 레저는 항상 git-committed 파일이다.** PR / 타 기기 가시성, 단일소스 전파, 도구 간
  대칭을 위해 학습 레저는 저장소에 커밋되는 마크다운(또는 계약이 정한 위치)으로 둔다.
  shared tier 정본과 각 도구별 tier 정본을 분리해 관리한다.
- **시스템 개선 제안:** 같은 tier 레저의 제안 섹션 + 구체적 placement(어느 파일 / 스킬 /
  훅을 어떻게 바꿀지)를 명시한다. 막연한 "나중에 개선"은 금지.
- **격리 프로필의 보조 미러(secondary, 정본 아님):** 각 도구의 격리 홈 아래 메모리 노트는
  git-ignored이라 PR / 타 기기에서 안 보이므로 **source of record가 될 수 없다.** 정본은
  항상 위의 git-committed 레저다.

## Promotion Gate (몇 회 -> 무슨 액션)
| Signal | Action |
|---|---|
| 1회 발생 (first occurrence) | record only -- 해당 tier 레저에 기록만 |
| 2회 발생 (second occurrence) | 레슨 제안 작성 (proposal) + 구체적 placement |
| 3회 이상, 또는 security / Done 관련 | 경계 안이면 저장소-로컬 skill / script / hook / doc 수정을 같은 턴에 구현(promote); 아니면 제안만 |
| host-global 대상 | 제안만 (proposal only). host-global 파일 mutate 금지 -- 매니저 승인 게이트 |

## 어느 "표면"으로 승격하나 (메모리에만 쌓지 말 것)
**메모리는 회상 기반이라 매번 안 읽힌다.** 재발 손해가 큰 교훈(비가역 / 보안 / Done / 반복
실수)을 메모리에만 두면 또 어긴다. "어디에 둘지"는 저장소의 레슨 승격 사다리 문서를 따른다
(정본 사다리: 메모리 < on-demand 스킬 < hot 규칙 < 훅 < 게이트 스크립트). 요지: **안
지키면 무슨 일이 나나의 강도**로 표면을 고른다 -- 비가역 / 보안 / Done 오판이면 메모리
단독 금지, **hot 규칙이나 게이트로 강제**한다. 메모리는 그 포인터 / 배경으로만.

## Enforcement Workflow
재발 방지가 암시되면 학습 레저(도구별 또는 shared)에 기록하고 멈추지 않는다.

1. **분류 + 기록.** 위 Tier 분류로 올바른 레저를 고르고, 항목 스키마에 맞는 항목을 추가한다:
   제목 / 무엇이 반복됐나 / 권장하는 가장 작은 수정 / 발생 횟수.
2. **승격 상태 판정.** Promotion Gate 표로 record_only / proposal_needed /
   implementation_needed 중 무엇인지 정한다.
3. `record_only`이면 다음 승격 트리거(몇 회째에 무엇이 일어나는지)를 보고한다.
4. `proposal_needed`이면 같은 tier 레저의 제안 섹션에 **구체적 placement**(대상 파일 / 스킬 /
   훅 + 변경 내용)를 적는다.
5. `implementation_needed`이면 같은 턴에 가장 좁은 저장소-로컬 / 현재-격리-프로필 수정을
   적용한다:
   - hook 필요: 훅 또는 enforcement 스크립트 추가 / 수정 + smoke test.
   - script / check 필요: 스크립트 추가 / 수정 후 검증.
   - skill workflow 필요: 스킬 업데이트 후 검증.
   - 지침 / instruction doc 필요: 편집 후 hot-context를 작게 유지(불필요하면 정확한 skip
     사유 기록).
   - host-global 대상: 제안만; host-global 파일은 mutate 금지.
6. 변경 동작을 **가장 좁은 명령**으로 검증한다(스킬 / 훅 변경은 실제 트리거로, 스크립트
   변경은 그 스크립트가 실제로 파싱 / 실행되는 셸로 실행). 변경된 셸 / 배치 스크립트는
   저장소의 텍스트 안전 게이트를 통과해야 한다.

수정이 불명확하면 시스템 제안을 만들고 빠진 증거를 명시한다 -- 학습 노트만 남기고 끝내지
않는다(끝까지-해결의 No Substitute Done과 동일 원칙).

## Helper script status
학습 헬퍼 스크립트(레슨 추가 / 검색 / 승격 판정)가 어느 도구 경로에 존재하는지는 도구마다
다를 수 있다. 헬퍼가 없는 경로에서는 레저를 **직접 편집하는 수동 절차**로 동작한다(학습
레저는 본래 git-committed 수동 파일이다 -- 정본은 학습 계약 문서). 자동 헬퍼가 반복적으로
필요해지면(2회+) 위 Promotion Gate에 따라 해당 도구의 스크립트 경로에 헬퍼를 만드는
follow-up을 등록한다. 새 셸 스크립트는 텍스트 안전(ASCII-safe / 인코딩) 규칙을 지키고, 그
스크립트가 실제로 실행되는 셸에서 검증한다.

## Manager Report
첫 문장은 쉬운 한국어 요약(공유 설계 계약의 4라벨 중 하나). 기술어 / 경로는 그 아래 증거
줄로.
- built / inspected: 남긴 교훈 후보 + 어느 tier 레저인지.
- tested / evidence: 반복 근거(발생 횟수)와 적용 검증 명령.
- manager run / paste: 매니저 승인이 필요한 경우의 문구(host-global / 파괴적 변경 등).
- blocked / unverified: 아직 반복성이 부족하거나 host-global proposal이라 보류인 것.

## Safety
PASS / 적용 / 검증은 명령 증거 없이 말하지 않는다(정적 doc 확인만으로는 동작 `UNVERIFIED`).
같은 blocker가 반복되면 반드시 올바른 tier 레저에 레슨 후보를 기록한다. host-global 파일은
mutate하지 않고 제안만 -- 매니저 승인 게이트. 매니저 보고는 쉬운 한국어, 4라벨 우선.
peer / recursive AI 호출은 하지 않는다(에이전트가 자기 subagent로 이 저장소 일을 하는
오케스트레이션은 허용).
