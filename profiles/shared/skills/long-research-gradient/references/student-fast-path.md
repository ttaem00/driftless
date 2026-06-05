# Student Fast Path Example

This reference is public-safe and intentionally small. Use it only when an
example output or UX fixture is needed.

## Input

```text
장기연구: 하이라이트 품질을 올려줘
내가 판단해야 할 것만 묻고, 조사-증거-다음 행동-경사하강 개선까지 네가 처리해줘.
```

## Expected Student-Facing Shape

```markdown
built/inspected:
- 하이라이트 품질을 올리는 첫 연구 스프린트를 잡았다.
- 이번에는 "좋은 하이라이트"를 관리자 수정 부담이 줄어드는지로 판단한다.

tested/evidence:
- Observed: 사용할 수 있는 품질 기준과 기존 검증 경로를 확인했다.
- Inferred: 첫 스프린트는 전체 자동화보다 작은 샘플 비교가 싸다.
- UNVERIFIED: 실제 품질 개선은 샘플 실행 전까지 확인 안 됨.

manager run/paste:
- 없음. 제품 방향이나 비용 승인이 필요한 단계가 아니다.

blocked/unverified:
- 실제 샘플 실행 전까지 성능 향상은 UNVERIFIED.

이번 경사하강:
- kept: 한 문장 시작 UX는 유지한다.
- changed now: 반복 확인은 작은 체크리스트나 gate로 옮긴다.
- issue/watch: 샘플 실행 증거가 없으면 follow-up으로 남긴다.
- saved tokens/time/intervention: 반복 설명을 줄일 수 있음, 수치는 UNVERIFIED.
- next sprint: 샘플 3-5개로 품질 기준을 검증한다.
```

## Rule

Never ask the student to choose a workflow engine, search provider, branch name,
test command, or GitHub action. Ask only for product meaning, credentials,
billing, public release, destructive action, host-global promotion, or user-data
decisions.
