# Starrail Sprint

Starrail Sprint는 증거 중심 작업을 위한 작은 공용 용어입니다. Claude, Codex와
작은 Hermes 어댑터가 같은 뜻을 사용하므로 학생이 별도 체계를 배울 필요가 없습니다.

- **Aemeth / 에이메스**: 데이터 기반 스프린트 스키마와 검증·피드백 고리
- **Stelle / 스텔레**: 입력·출력·검증·예외 계약이 있는 한 실행 단계
- **StarrailTopology / 스타레일 토폴로지 / 스타레일**: 단계, 산출물, 경계, 의존성과 피드백 간선의 방향 그래프
- **Trailblazer / 개척자 / 개척자Trailblazer**: 그래프를 검증·순회하고 실패를 차단하는 영수증 실행기

공개 안전 예제를 실행합니다.

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-StarrailSprint.ps1 -TopologyPath .\examples\starrail-sprint\topology.pass.json -ContractPath .\.runtime\codex-home\shared\contract\STARRAIL_SPRINT_CONTRACT.json -ReceiptPath .\.runtime\starrail-sprint\receipt.json
```

`Invoke-AemethSprint.ps1`도 같은 실행기를 부르는 호환 이름입니다. 두 명령의
결과가 같아야만 검사를 통과합니다.

모든 필수 검증이 통과할 때만 종료 코드가 0입니다. 정본 계약과 호환 필드는
`profiles/shared/contract/STARRAIL_SPRINT_CONTRACT.json` 한 곳에 있으며 설치 시
Claude와 Codex의 격리 홈에 같은 skill/contract가 복사됩니다. 설치기의
`-Tool hermes` / `--hermes`를 쓰면 이 기술, 계약, 보호 별칭만 저장소 안
`.runtime/hermes-home`에도 복사됩니다. `hermes-worker`도 같은 공개 JSON 필드를
사용합니다. 이 Hermes 어댑터는 완전한 세 번째 Driftless 프로필이 아닙니다.

영수증 쓰기는 생성 증거 폴더 `.runtime/starrail-sprint` 아래로 제한됩니다.
토폴로지와 계약은 저장소 안에서만 읽습니다. `README.md` 같은 소스 파일은
PowerShell 또는 Python 직접 실행 어느 쪽에서도 영수증 대상으로 사용할 수 없습니다.

공용 언어 계약은 `aemeth-sprint.v1`, 하위 토폴로지 문서는
`starrail-topology.v1`, 영구 실행 영수증은 `trailblazer-run-receipt.v1`입니다.

## 모든 Aemeth의 문서 정리

프로젝트와 버전에 관계없이 하나의 기존 문서 안내를 진입점으로 사용하고,
계획·설계·실험·결정·시행착오·역사·원자료 위치를 역할별로 나눕니다. 자세한
[공통 정리 원칙](../en/starrail-sprint.md#document-organization)을 따릅니다.

- `plans/`: 사용자 목표, 범위, 완료 조건과 다음 개발·실험 계획.
- `design/`: 실제 구조와 입력·출력·생산자·소비자 계약, 현재와 제안의 구분.
- `experiments/`: 가설·입력·ref·방법·관측 결과·한계와 실패/미결 시도.
- `decisions/`: 유지·추가·수정·보류·기각·제거한 이유와 대안·근거.
- `lessons/`: 확인 원인과 추정, 교정, 지킬 성공 메커니즘, 재시도 조건.
- `history/`: 옛 계획·설계·실행 지시. 당시 지시는 현재 실행 권한이 아닙니다.
- `sources/`: 원기록 위치·revision·가용성·미확인 및 미독 범위.

짧은 작업은 기존 문서의 절 구분으로 충분합니다. 빈 폴더나 새 관제 단계를
만들지 않습니다. 문서명은 역할과 주제가 드러나게 하고 고정된 실험에는 날짜나
시도 ID를 붙입니다. 원문·출처·옛 제목 링크·이동 안내와 다른 소유자의 최신 변경을
보존합니다. 정확히 중복된 본문은 한곳에 온전히 남기고 링크로 연결합니다.
실험→결정→교훈→현재 계획을 연결하며, 미확인 자료를 삭제나 복원 완료로
단정하지 않습니다. 재개 시 관련 변경과 근거를 읽되 매번 모든 역사를 반복해
읽지는 않습니다. 문서·링크 검사, 구현, 실제 품질, main 및 stable 반영은 각각
확인합니다. 조회 요청은 읽기 전용이며 이 원칙이 별도 실행·승인 gate를 만들지 않습니다.
