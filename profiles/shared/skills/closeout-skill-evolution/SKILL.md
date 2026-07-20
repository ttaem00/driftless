---
name: closeout-skill-evolution
description: "Use when: 작업 마무리에서 배운 반복 문제를 기존 스킬 수정, 새 얇은 래퍼, 새 스킬, 스크립트/게이트, 기록만, 변경 없음 중 어디에 둘지 판정하고 실제 검증까지 닫는다. 사용자가 마무리하면서 스킬도 개선·추가하라고 하거나 반복 실패를 재사용 자산으로 승격하라고 할 때 사용한다."
---

# Closeout Skill Evolution

## Improvement Principle

Use root-cause analysis and root-cause fixes. Prefer principle-based guidance
that transfers to similar work; reject spec/case overfitting and special-casing
unless bounded evidence proves the exception reduces user effort or risk.

학습을 규칙 증가와 동일시하지 않는다. 다음 실행의 시간·토큰·관리자 개입·비용·오류를 실제로 줄이는 가장 작은 자산을 고른다.

## 절차

1. `codex-learning-loop` 또는 도구별 learning loop로 교정, 근본 원인, 반복 가능성을 기록한다.
2. 등록된 스킬·스크립트·훅·문서를 검색하고 최소 두 기존 자산을 대안으로 비교한다.
3. [decision-matrix.md](references/decision-matrix.md)로 `update_existing`, `thin_wrapper`, `create_new`, `script_or_gate`, `record_only`, `no_change`를 하나 선택한다.
4. 새 스킬은 독립적인 트리거와 산출물이 있고 두 번째 사용 사례가 설명될 때만 만든다. 한 사례용이면 기존 스킬이나 실행 코드에 둔다.
5. `skill-creator`로 골격을 만들고 `instruction-edit-checklist`로 배치·과발화·중복을 확인한다.
6. 구조 검증, 부정 fixture, 실제 호출 예시를 통과시킨다. 등록 목록과 생성 홈은 소스 템플릿과 별도로 검증한다.
7. public-safe 원칙은 Driftless 공유 계층, 비공개 운영 세부는 CC, 도구 특화 반복 실수는 해당 프로필에 둔다.

최종 출력에는 `root_cause_class`, `decision`, `existing_assets_considered`, `placement`, `expected_saving`, `validation`, `optimization_applied`를 포함한다. 마무리 시간이 부족하면 새 스킬을 반쯤 만들지 말고 검증 가능한 `record_only`로 끝낸다.
