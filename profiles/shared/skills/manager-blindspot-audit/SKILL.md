---
name: manager-blindspot-audit
description: "Use when: 완료 주장 뒤 비개발자 관리자가 놓치기 쉬운 운영·증거·복구·비용·보안·사용성 위험을 최소 12개 관점에서 감사하고 해결 우선순위를 브리핑한다. '완료 기준을 검증하고 내가 못 본 것도 찾아라', 출시 전 관리자 감사를 요청할 때 사용한다. 구현 자체나 일반 코드 리뷰에는 사용하지 않는다."
---

# Manager Blindspot Audit

## Improvement Principle

Use root-cause analysis and root-cause fixes. Prefer principle-based guidance
that transfers to similar work; reject spec/case overfitting and special-casing
unless bounded evidence proves the exception reduces user effort or risk.

12개의 문제를 억지로 만들어내지 말고, 최소 12개 **관점**을 실제 증거로 검사한다.

## 절차

1. 원래 목표·완료 기준·명시적 제외 범위를 먼저 고정한다.
2. [audit-categories.md](references/audit-categories.md)에서 관련 관점 12개 이상을 검사한다.
3. 각 관점을 `PASS`, `FINDING`, `NOT_APPLICABLE`, `UNVERIFIED`로 기록하고 근거를 연결한다.
4. 발견 사항은 `blocker`, `warning`, `backlog`, `rejected`, `out_of_scope` 중 하나로 분류한다.
5. blocker는 현재 목표의 거짓 완료, 보안/데이터 손실, 복구 불능, 필수 사용자 흐름 실패일 때만 쓴다. 제외 범위의 문제는 blocker가 될 수 없다.
6. 감사 요청은 읽기 전용이다. 사용자가 수정까지 요청한 경우에만 원래 범위 안의 blocker를 고친다.

## 관리자 보고

먼저 `완료 판정: 충족/부분 충족/미충족`을 말한다. 그 뒤 `무엇을 봤나 / 결과 / 왜 중요한가 / 해결 / 현재 스프린트 포함 여부` 표를 쓴다. 발견이 없으면 “12개 관점 검사, 추가 문제 없음”이라고 보고하며 숫자를 채우기 위해 가짜 항목을 만들지 않는다.
