---
name: durable-evidence-audit
description: "Use when: 완료 증거 번들이 원본 리비전과 결합되고, 해시가 맞고, 중첩·Base64 내용에도 절대경로·세션 ID·비밀값이 없으며, 다른 세션에서 재검증 가능한지 검사한다. 증거 보존·감사·인계 안전성을 확인할 때 사용한다."
---

# Durable Evidence Audit

## Improvement Principle

Use root-cause analysis and root-cause fixes. Prefer principle-based guidance
that transfers to similar work; reject spec/case overfitting and special-casing
unless bounded evidence proves the exception reduces user effort or risk.

화면에 보였다는 사실과 나중에 다시 검증할 수 있다는 사실을 구분한다.

## 절차

1. 증거가 `source_revision`, 상대 경로, 파일 SHA-256, 번들 digest, 재현 명령을 포함하는지 확인한다.
2. 평문뿐 아니라 JSON 안 문자열과 `content_base64`를 재귀적으로 펼쳐 절대경로, 태스크 URI/원시 세션 ID, secret 형태를 검사한다.
3. 값 자체는 출력하지 않고 위치와 규칙 이름만 보고한다.
4. 정적 검사 증거를 실제 동작 PASS로 승격하지 않는다.
5. 저장소의 `scripts/validate_manager_closeout.py --kind evidence --input <file>`를 실행한다.

결과는 `PASS`, `FAIL`, `UNVERIFIED`와 재현 명령으로 남긴다. FAIL인 번들은 배포·공개·부모 채택 증거로 사용하지 않는다.
