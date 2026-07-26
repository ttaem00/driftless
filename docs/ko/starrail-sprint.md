# Starrail Sprint

Starrail Sprint는 증거 중심 작업을 위한 작은 공용 용어입니다. Claude와 Codex가
같은 뜻을 사용하므로 학생이 두 개의 오케스트레이션 체계를 배울 필요가 없습니다.

- **Stelle**: 범위가 명확한 한 단계
- **StarrailTopology**: 단계의 의존성을 지키는 실행 순서
- **Aemeth**: 실패한 검증 증거를 차단하는 문
- **Trailblazer**: 토폴로지를 실행하고 영수증 하나를 출력하는 실행기

공개 안전 예제를 실행합니다.

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-StarrailSprint.ps1 -TopologyPath .\examples\starrail-sprint\topology.pass.json -ContractPath .\.runtime\codex-home\shared\contract\STARTRAIL_SPRINT_CONTRACT.json -ReceiptPath .\.runtime\starrail-sprint\receipt.json
```

모든 필수 검증이 통과할 때만 종료 코드가 0입니다. 정본 계약과 호환 필드는
`profiles/shared/contract/STARTRAIL_SPRINT_CONTRACT.json` 한 곳에 있으며 설치 시
Claude와 Codex의 격리 홈에 같은 skill/contract가 복사됩니다. Hermes와
`hermes-worker`는 공개 JSON 호환 필드를 사용할 수 있지만 Driftless 프로필은
Claude와 Codex 두 개뿐입니다.
