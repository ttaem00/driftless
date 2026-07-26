# Starrail Sprint

Starrail Sprint는 증거 중심 작업을 위한 작은 공용 용어입니다. Claude와 Codex가
같은 뜻을 사용하므로 학생이 두 개의 오케스트레이션 체계를 배울 필요가 없습니다.

- **Aemeth / 에이메스**: 데이터 기반 스프린트 스키마와 검증·피드백 고리
- **Stelle / 스텔레**: 입력·출력·검증·예외 계약이 있는 한 실행 단계
- **StarrailTopology / 스타레일 토폴로지 / 스타레일**: 단계, 산출물, 경계, 의존성과 피드백 간선의 방향 그래프
- **Trailblazer / 개척자 / 개척자Trailblazer**: 그래프를 검증·순회하고 실패를 차단하는 영수증 실행기

공개 안전 예제를 실행합니다.

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-StarrailSprint.ps1 -TopologyPath .\examples\starrail-sprint\topology.pass.json -ContractPath .\.runtime\codex-home\shared\contract\STARRAIL_SPRINT_CONTRACT.json -ReceiptPath .\.runtime\starrail-sprint\receipt.json
```

모든 필수 검증이 통과할 때만 종료 코드가 0입니다. 정본 계약과 호환 필드는
`profiles/shared/contract/STARRAIL_SPRINT_CONTRACT.json` 한 곳에 있으며 설치 시
Claude와 Codex의 격리 홈에 같은 skill/contract가 복사됩니다. Hermes와
`hermes-worker`는 공개 JSON 호환 필드를 사용할 수 있지만 Driftless 프로필은
Claude와 Codex 두 개뿐입니다.

영수증 쓰기는 생성 증거 폴더 `.runtime/starrail-sprint` 아래로 제한됩니다.
토폴로지와 계약은 저장소 안에서만 읽습니다. `README.md` 같은 소스 파일은
PowerShell 또는 Python 직접 실행 어느 쪽에서도 영수증 대상으로 사용할 수 없습니다.

공용 언어 계약은 `aemeth-sprint.v1`, 하위 토폴로지 문서는
`starrail-topology.v1`, 영구 실행 영수증은 `trailblazer-run-receipt.v1`입니다.
