# 실행 계약

필수 필드: `goal`, `target_minutes`, `contingency_minutes`, `hard_stop_minutes`, `scope_in`, `scope_out`, `proof_rows`, `checkpoints`, `evidence_delta`, `state`, `next_action`.

- `target <= contingency <= hard_stop`이어야 한다.
- 체크포인트는 하드스톱보다 앞서야 한다.
- Codex/Claude는 작업 계획과 저장소 증거를 갱신한다.
- Hermes Kanban은 네이티브 task의 `parent_task_id`, `metadata.scope_lock`, `metadata.hard_stop_at`, `metadata.evidence_delta`, `last_heartbeat`를 사용한다. 별도 보드나 데몬을 만들지 않는다.
- Orphanless는 기존 owner/guardian/proof/adoption 투영만 사용하며 writer를 추가하지 않는다.
- Ponytail은 관리자 상태 요약만 유지하고 실행 권한을 새로 만들지 않는다.

최종 보고: `built/inspected`, `tested/evidence`, `manager run/paste`, `blocked/unverified`, `final state`.
