# Wuther Codemap

private 패키지와 공개 Driftless 패키지는 같은
`schema_version: wuther-codemap.v1` 계약과 생성기를 사용합니다.

Wuther Codemap은 낯선 저장소를 비개발자 관리자와 AI 에이전트가 같은 구조로
이해하게 해 줍니다. 버전이 있는 JSON manifest 하나를 검토하면 외부 서비스나
별도 렌더러 없이 다음 세 파일을 만듭니다.

- `manager.html`: 쉬운 설명, 실제 edge 기반 데이터 흐름, 분야, 목적 중심 단계,
  연결 의미와 데이터 생명주기를 보여 주는 화면
- `llm-context.json`: 에이전트와 도구가 읽는 구조화 데이터
- `llm-context.md`: 프롬프트와 리뷰에 붙이기 쉬운 Markdown

## 공개 예제 실행

Driftless 저장소 루트에서 실행하세요.

```powershell
$example = '.\examples\wuther-codemap\school-media-repository'
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-WutherCodemap.ps1 `
  -Root $example -ManifestPath codemap.json -Clean
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-WutherCodemap.ps1 `
  -Root $example -ManifestPath codemap.json -Check
```

결과는 예제 저장소의 `.runtime/wuther-codemap/`에 생깁니다. 관리자는
`manager.html`을 열고, AI 에이전트에는 JSON 또는 Markdown을 전달하면 됩니다.

## 다른 저장소에 적용

1. 예제 `codemap.json`을 대상 저장소에 복사합니다.
2. 실제로 확인한 소스 파일을 근거로 합성 예제 내용을 바꿉니다.
3. 저장소 상대 `code_refs`, 각 단계의 목적·위험·검증·입출력과 각 데이터의
   형식·출처·변환·저장·소비자·검증·누락 영향을 유지합니다.
4. 대상 저장소를 `-Root`로 지정해 생성합니다.
5. 소스 구조나 manifest가 바뀌면 `-Check`로 세 화면의 동기화를 확인합니다.

스키마는 필수 의미, 코드 근거, 위험, 검증, 데이터 생명주기가 빠진 manifest를
거부합니다. 생성기는 중복 ID, 잘못된 단계·분야·데이터 참조, 순환, 비공개
호스트 경로, 저장소 밖 manifest, symlink와 junction 출력 탈출도 거부합니다.

기본 출력은 대상 저장소 아래 `.runtime/wuther-codemap`입니다. `-Check`는 파일을
수정하지 않습니다. `-Clean`은 Wuther가 소유한 세 파일만 다시 만들고 다른
파일은 보존합니다. 소유권 표식이 없는 기존 폴더에는 쓰지 않습니다. 기본 Python
생성기는 `jsonschema`를 사용하며, 외부 렌더러는 JSON을 소비하는 선택 사항입니다.

검증 명령:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-WutherCodemap.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-InstallerMaterialization.ps1
```

`examples/wuther-codemap/canonical-v1-vector.json`은 스키마, 생성기, fixture와
세 산출물의 지문을 고정합니다. private/public 계약이 조용히 갈라지면 출시 전에
검사가 실패합니다.

두 번째 명령은 저장소 내부의 Codex/Claude 활성 홈 모두에 공유 스킬을 설치하고,
정확한 `wuther-codemap` 트리거가 보이는지 확인합니다. 호스트 전역 프로필은 읽거나
수정하지 않습니다.
