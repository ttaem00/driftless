---
name: apply-driftless
description: >
  드리프트리스적용 apply-driftless: 사용자가 "이 레포 적용해줘 / set me up with
  Driftless / 이 저장소를 내 Claude(또는 Codex)에 적용 / install this repo for
  yourself"라고 하면, 에이전트가 스스로 Driftless 격리 프로필을 설치·검증·보고하는
  기계적 절차. 설치 전 MCP/의존성/플러그인은 반드시 묻고(기본 No), 호스트 전역
  설정은 절대 건드리지 않으며, 끝에 평이한 말로 무엇을 했고 무엇을 결정해야 하는지
  보고한다.
  Use when the user asks to apply / set up / install this repo into their Claude
  Code or OpenAI Codex environment, or asks the agent to onboard them to Driftless.
  Trigger / 트리거: "이 레포 적용", "적용해줘", "이 저장소를 나한테", "드리프트리스
  설정", "apply this repo", "apply driftless", "set me up", "install this repo
  for yourself", "onboard me", "이 레포로 나 세팅".
---
## Improvement Principle

Use root-cause analysis and root-cause fixes, not symptom patches. Generalize as principle-based guidance or design principles; avoid spec/case overfitting and special-casing unless evidence proves a bounded exception reduces user effort, maintainer effort, maintenance risk, or safety burden.
# Apply Driftless (이 레포를 내 Claude/Codex에 적용)

이 스킬은 사용자가 "이 레포 적용해줘" 한 문장을 말했을 때 **에이전트가 스스로 따르는
절차**다. 사용자는 코드를 쓰지 않는다. 에이전트가 감지·설치·검증·보고를 한다.

## 절대 규칙 (load-bearing)
- **호스트 전역 설정을 절대 건드리지 않는다.** 격리 홈은 항상 이 레포 안(`.runtime/`)에 만든다. 사용자의 평소 `~/.claude`·`~/.codex`는 읽지도 쓰지도 않는다.
- **추가 설치(MCP 서버·의존성·플러그인)는 반드시 먼저 묻고, 기본값은 "아니오".** 사용자가 명시적으로 동의할 때만 설치한다. 무엇을·왜 설치하는지 평이하게 설명한 뒤 묻는다.
- **파괴적·되돌릴 수 없는 일, 비밀정보, 돈/크레딧, 공개 발신은 하지 않는다** — 그런 결정은 사용자에게 한 문장으로 돌려준다.

## 절차
1. **도구 감지.** 지금 도는 게 Claude Code인지 Codex인지 판단한다(불확실하면 사용자에게 1·2·3=둘 다 중 고르게 한다).
2. **드라이런 먼저(부작용 0).** 무엇을 할지 보여준다:
   - macOS/Linux: `sh ./install.sh --dry-run --both` (또는 `--claude`/`--codex`)
   - Windows: `pwsh.exe -ExecutionPolicy Bypass -File .\install.ps1 -DryRun -Tool both`
   계획(어떤 격리 홈이 `.runtime/` 아래 어디에 생기는지)을 평이하게 요약한다.
3. **실제 설치.** 사용자가 진행에 동의하면 `--dry-run`을 빼고 같은 명령을 실행한다. 설치기는 격리 홈을 materialize하고, 추가 설치 항목은 각각 "아니오" 기본으로 묻는다 — 그 프롬프트를 그대로 사용자에게 전달한다.
4. **검증(증거 필수, 추측 금지).** 설치 후 실제로 확인한다:
   - 격리 홈이 `.runtime/claude-home`(및/또는 `.runtime/codex-home`)에 생겼는가
   - 호스트 전역 홈이 안 바뀌었는가
   - 안전 게이트가 통과하는가: `Test-Containment.ps1`, `Test-ProfileMirrorParity.ps1`
   확인 못 한 건 "됐다"고 하지 말고 `UNVERIFIED`로 보고한다.
5. **평이한 보고.** 네 가지 라벨 중 하나로 시작: 완료 / 당신의 결정 필요 / 막힘 / 진행 중. 무엇이 설치됐고, 다음에 무엇을 하면 되는지("자기 전에 프롬프트 하나 붙여넣기"), 사용자가 결정할 것(추가 MCP/플러그인 등)을 적는다. 원시 명령/경로는 요약 뒤 증거로.

## 개선 제안 (선택)
적용이 끝나면, 사용자 환경에 맞는 작은 개선 1-2개를 **제안만** 한다(자동 적용 금지):
예) "이 저장소에 이슈가 많으니 밤샘 자동작업(overnight)을 한 번 돌려볼 수 있어요",
"Codex를 쓰시면 goal 모드, Claude면 ultracode가 큰 작업에 맞아요." 제안은 사용자가
원할 때만 실행한다.

## 안 하는 것
- 호스트 전역 프로필 수정 · 비밀/자격증명 취급 · 묻지 않은 설치 · 외부 발신/공개 ·
  되돌릴 수 없는 작업. 전부 사용자 결정으로 돌린다.
