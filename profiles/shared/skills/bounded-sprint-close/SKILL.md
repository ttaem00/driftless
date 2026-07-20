---
name: bounded-sprint-close
description: "Use when: 시간 제한 스프린트로 범위를 잠그고, 증거가 늘어나는 작업만 진행하며, 완료 또는 하드스톱 보고까지 닫는다. 사용자가 몇 분/몇 시간 안에 끝내라, 일이 늘어진다, 본질만 마무리하라, 완료 기준까지 실행하라고 할 때 사용한다. 단순 일정 추정이나 읽기 전용 상태 질문에는 사용하지 않는다."
---

# Bounded Sprint Close

## Improvement Principle

Use root-cause analysis and root-cause fixes. Prefer principle-based guidance
that transfers to similar work; reject spec/case overfitting and special-casing
unless bounded evidence proves the exception reduces user effort or risk.

시간 약속을 낙관적 숫자가 아니라 실행 계약으로 바꾼다.

## 절차

1. `intake-preflight`로 직접 완료 경로와 기존 자산을 10% 이내에서 찾는다.
2. 목표 시간, 비상 범위, 하드스톱, 포함 범위, 제외 범위, 완료 증거를 기록한다.
3. `wuther-codemap`이 있으면 관련 경로만 보고 영향 범위를 잠근다. 코드맵이 오래됐으면 사실로 사용하지 말고 재생성/검증한다.
4. 상태를 `SCOPE_LOCKED -> RUNNING -> VERIFYING -> MANAGER_AUDIT -> DONE|STOPPED`로 이동한다.
5. 매 체크포인트에는 말이 아니라 새 커밋, 통과한 테스트, 닫힌 증거 행처럼 `evidence_delta`를 남긴다. 두 체크포인트 연속 0이면 원인을 좁히고 직접 완료 경로로 되돌린다.
6. 마지막 10%는 새 구현을 금지하고 검증, `manager-blindspot-audit`, 정리, 인계에만 쓴다.
7. 하드스톱 전에 완료하지 못하면 `STOPPED`로 끝내고 완료된 것, 정확한 막힘, 남은 최소 원자, 재현 명령을 보고한다. 조용히 계속하지 않는다.

## 범위 잠금

- 새 티켓, 새 세션, 새 자동화, 새 프레임워크는 원래 완료 조건을 직접 막는 최소 원자가 아니면 만들지 않는다.
- 감사에서 찾은 개선은 현재 완료 조건과 분리한다. 안전/데이터 손실/거짓 완료가 아니면 현재 스프린트를 재개방하지 않는다.
- 구현 요청이면 끝까지 구현·검증한다. 상태/감사 요청이면 외부 상태를 바꾸지 않는다.
- `DONE`은 모든 필수 증거 행이 PASS이고 관리자 감사에 미해결 blocker가 없을 때만 허용한다.

계약 필드와 도구별 어댑터는 [contract.md](references/contract.md)를 따른다.
