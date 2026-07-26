#!/usr/bin/env python3
"""Public-safe deterministic Starrail sprint runtime."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

ID_PATTERN = re.compile(r"^[a-z][a-z0-9._-]*$")
REPO_ROOT = Path(__file__).resolve().parents[2]
EVIDENCE_ROOT = (REPO_ROOT / ".runtime" / "starrail-sprint").resolve()
CANONICAL_ALIASES = {
    "Aemeth": ["Aemeth", "에이메스"],
    "Stelle": ["Stelle", "스텔레"],
    "StarrailTopology": ["StarrailTopology", "스타레일 토폴로지", "스타레일"],
    "Trailblazer": ["Trailblazer", "개척자", "개척자Trailblazer"],
}


def resolve_repo_path(raw_path: Path, *, must_exist: bool) -> Path:
    candidate = raw_path if raw_path.is_absolute() else REPO_ROOT / raw_path
    candidate = candidate.resolve(strict=must_exist)
    try:
        candidate.relative_to(REPO_ROOT)
    except ValueError as exc:
        raise ValueError(f"path must stay inside the Driftless repository: {raw_path}") from exc
    return candidate


def resolve_receipt_path(raw_path: Path) -> Path:
    candidate = resolve_repo_path(raw_path, must_exist=False)
    try:
        candidate.relative_to(EVIDENCE_ROOT)
    except ValueError as exc:
        raise ValueError(f"receipt path must stay under .runtime/starrail-sprint: {raw_path}") from exc
    return candidate


class Aemeth:
    """Data-driven validation gate and feedback policy."""

    def __init__(self, sprint_spec: dict[str, Any]):
        self.required_status = str(sprint_spec.get("required_status", "PASS"))
        if self.required_status != "PASS":
            raise ValueError("Aemeth required_status must be PASS; failed or unproven work cannot be configured as success")
        if sprint_spec.get("require_evidence") is not True:
            raise ValueError("Aemeth require_evidence must be true in v1; unproven work cannot pass")

    def verify(self, step: "Stelle") -> tuple[bool, str]:
        verification = step.verification
        passed = verification.get("status") == self.required_status
        evidence = verification.get("evidence")
        if not isinstance(evidence, str) or not evidence.strip():
            return False, "verification evidence is missing"
        normalized_evidence = evidence.strip()
        if not passed:
            return False, normalized_evidence
        return True, normalized_evidence


@dataclass(frozen=True)
class Stelle:
    """One bounded topology step."""

    id: str
    action: str
    depends_on: tuple[str, ...]
    input_contract: dict[str, Any]
    output_contract: dict[str, Any]
    verification: dict[str, Any]
    exception_contract: dict[str, Any]

    @classmethod
    def from_dict(cls, raw: dict[str, Any]) -> "Stelle":
        step_id = raw.get("id")
        action = raw.get("action")
        dependencies = raw.get("depends_on", [])
        input_contract = raw.get("input")
        output_contract = raw.get("output")
        verification = raw.get("verification")
        exception_contract = raw.get("exception")
        if not isinstance(step_id, str) or not ID_PATTERN.fullmatch(step_id):
            raise ValueError("each step id must match ^[a-z][a-z0-9._-]*$")
        if not isinstance(action, str) or not action.strip():
            raise ValueError(f"step {step_id}: action must be non-empty")
        if not isinstance(dependencies, list) or not all(isinstance(item, str) for item in dependencies):
            raise ValueError(f"step {step_id}: depends_on must be a string array")
        if not isinstance(verification, dict):
            raise ValueError(f"step {step_id}: verification is required")
        if not isinstance(input_contract, dict) or not isinstance(output_contract, dict):
            raise ValueError(f"step {step_id}: input and output contracts are required")
        if not isinstance(exception_contract, dict) or exception_contract.get("on_failure") not in {"stop", "feedback"}:
            raise ValueError(f"step {step_id}: exception.on_failure must be stop or feedback")
        return cls(step_id, action.strip(), tuple(dependencies), input_contract, output_contract, verification, exception_contract)


class StarrailTopology:
    """Validated directed acyclic graph of Stelle units."""

    def __init__(self, topology_id: str, steps: list[Stelle], compatibility: dict[str, str], aemeth_spec: dict[str, Any], artifacts: list[dict[str, Any]], boundary: dict[str, Any], feedback_edges: list[dict[str, Any]]):
        if not ID_PATTERN.fullmatch(topology_id):
            raise ValueError("topology_id must match ^[a-z][a-z0-9._-]*$")
        if not steps:
            raise ValueError("topology must contain at least one step")
        self.topology_id = topology_id
        self.steps = steps
        self.compatibility = compatibility
        self.aemeth_spec = aemeth_spec
        self.artifacts = artifacts
        self.boundary = boundary
        self.feedback_edges = feedback_edges
        if not isinstance(artifacts, list) or not artifacts or not all(isinstance(item, dict) and isinstance(item.get("id"), str) and item.get("id") for item in artifacts):
            raise ValueError("topology artifacts must be an array of named objects")
        if (
            not isinstance(boundary, dict)
            or not isinstance(boundary.get("in_scope"), list)
            or not isinstance(boundary.get("out_of_scope"), list)
            or not all(isinstance(item, str) for item in boundary.get("in_scope", []) + boundary.get("out_of_scope", []))
        ):
            raise ValueError("topology boundary requires string arrays in_scope and out_of_scope")
        if not isinstance(feedback_edges, list):
            raise ValueError("feedback_edges must be an array")
        self._by_id = {step.id: step for step in steps}
        if len(self._by_id) != len(steps):
            raise ValueError("step ids must be unique")
        for step in steps:
            missing = [item for item in step.depends_on if item not in self._by_id]
            if missing:
                raise ValueError(f"step {step.id}: missing dependencies: {', '.join(missing)}")
        for edge in feedback_edges:
            if not isinstance(edge, dict) or edge.get("from") not in self._by_id or edge.get("to") not in self._by_id or edge.get("when") != "FAIL":
                raise ValueError("each feedback edge requires existing from/to step ids and when=FAIL")
            if self._by_id[str(edge.get("from"))].exception_contract.get("on_failure") != "feedback":
                raise ValueError(f"step {edge.get('from')}: feedback edge requires exception.on_failure=feedback")
        for step in steps:
            matching_edges = [edge for edge in feedback_edges if edge.get("from") == step.id and edge.get("when") == "FAIL"]
            if step.exception_contract.get("on_failure") == "feedback" and len(matching_edges) != 1:
                raise ValueError(f"step {step.id}: feedback policy requires exactly one matching FAIL feedback edge")
        self.ordered_steps()

    @classmethod
    def from_dict(cls, raw: dict[str, Any]) -> "StarrailTopology":
        if not isinstance(raw, dict):
            raise ValueError("topology document must be a JSON object")
        if raw.get("schema_version") != "starrail-topology.v1":
            raise ValueError("schema_version must be starrail-topology.v1")
        steps_raw = raw.get("steps")
        if not isinstance(steps_raw, list):
            raise ValueError("topology steps must be an array")
        if not all(isinstance(item, dict) for item in steps_raw):
            raise ValueError("each topology step must be a JSON object")
        compatibility = raw.get("compatibility", {})
        if not isinstance(compatibility, dict):
            raise ValueError("compatibility must be an object")
        normalized = {
            "worker_role": str(compatibility.get("worker_role", "worker")),
            "route": str(compatibility.get("route", "local")),
        }
        aemeth_spec = raw.get("aemeth")
        if not isinstance(aemeth_spec, dict):
            raise ValueError("aemeth sprint schema is required")
        return cls(
            str(raw.get("topology_id", "")),
            [NewStelleStep(item) for item in steps_raw],
            normalized,
            aemeth_spec,
            raw.get("artifacts", []),
            raw.get("boundary", {}),
            raw.get("feedback_edges", []),
        )

    def ordered_steps(self) -> list[Stelle]:
        pending = {step.id: set(step.depends_on) for step in self.steps}
        ordered: list[Stelle] = []
        while pending:
            ready = sorted(step_id for step_id, dependencies in pending.items() if not dependencies)
            if not ready:
                raise ValueError("topology contains a dependency cycle")
            for step_id in ready:
                ordered.append(self._by_id[step_id])
                del pending[step_id]
                for dependencies in pending.values():
                    dependencies.discard(step_id)
        return ordered


AemethExecutionLanguage = Aemeth
StelleStepContract = Stelle
StarrailTopologyGraph = StarrailTopology


def NewStelleStep(raw: dict[str, Any]) -> StelleStepContract:
    """Build one canonical Stelle step contract."""

    return StelleStepContract.from_dict(raw)


def NewStarrailTopology(raw: dict[str, Any]) -> StarrailTopologyGraph:
    """Build the canonical Starrail topology graph."""

    return StarrailTopologyGraph.from_dict(raw)


def NewAemethSprint(raw: dict[str, Any]) -> StarrailTopologyGraph:
    """Build one Aemeth sprint from its subordinate topology document."""

    return NewStarrailTopology(raw)


def _run_trailblazer(topology: StarrailTopologyGraph) -> dict[str, Any]:
    """Traverse a topology and stop at the first failed Aemeth gate."""

    rows: list[dict[str, Any]] = []
    completed: set[str] = set()
    status = "PASS"
    blocked_at: str | None = None
    feedback: dict[str, str] | None = None
    gate = AemethExecutionLanguage(topology.aemeth_spec)
    for step in topology.ordered_steps():
        if any(item not in completed for item in step.depends_on):
            status, blocked_at = "BLOCKED", step.id
            rows.append({"id": step.id, "status": "BLOCKED", "action": step.action, "evidence": "dependency did not pass"})
            break
        passed, evidence = gate.verify(step)
        row_status = "PASS" if passed else "FAIL"
        rows.append({"id": step.id, "status": row_status, "action": step.action, "input": step.input_contract, "output": step.output_contract, "verification": step.verification, "exception": step.exception_contract, "evidence": evidence})
        if not passed:
            status, blocked_at = "BLOCKED", step.id
            edge = next((item for item in topology.feedback_edges if item.get("from") == step.id and item.get("when") == "FAIL"), None)
            if edge:
                feedback = {"from": step.id, "to": str(edge.get("to")), "reason": evidence}
            break
        completed.add(step.id)
    return {
        "schema_version": "trailblazer-run-receipt.v1",
        "runtime_identifiers": {
            "objects": ["AemethExecutionLanguage", "StelleStepContract", "StarrailTopologyGraph", "TrailblazerExecutor"],
            "functions": ["New-AemethSprint", "New-StelleStep", "New-StarrailTopology", "Invoke-Trailblazer"],
        },
        "topology_id": topology.topology_id,
        "status": status,
        "blocked_at": blocked_at,
        "compatibility": topology.compatibility,
        "boundary": topology.boundary,
        "artifacts": topology.artifacts,
        "feedback": feedback,
        "steps": rows,
        "summary": {"passed": len(completed), "total": len(topology.steps)},
    }


class TrailblazerExecutor:
    """Contained executor for one verified Starrail topology."""

    def invoke(self, topology: StarrailTopologyGraph) -> dict[str, Any]:
        return _run_trailblazer(topology)


def InvokeTrailblazer(topology: StarrailTopologyGraph) -> dict[str, Any]:
    """Invoke the canonical Trailblazer executor."""

    return TrailblazerExecutor().invoke(topology)


# Backward-compatible public name retained for callers of the first adapter.
Trailblazer = InvokeTrailblazer


def main() -> int:
    parser = argparse.ArgumentParser(description="Run a public-safe Starrail evidence sprint.")
    parser.add_argument("--topology", type=Path, required=True)
    parser.add_argument("--contract", type=Path)
    parser.add_argument("--receipt", type=Path)
    args = parser.parse_args()
    receipt_path: Path | None = None
    try:
        topology_path = resolve_repo_path(args.topology, must_exist=True)
        receipt_path = resolve_receipt_path(args.receipt) if args.receipt else None
        if args.contract:
            contract_path = resolve_repo_path(args.contract, must_exist=True)
            contract = json.loads(contract_path.read_text(encoding="utf-8"))
            if (
                contract.get("schema_version") != "aemeth-sprint.v1"
                or contract.get("receipt_schema") != "trailblazer-run-receipt.v1"
                or set(contract.get("profiles", [])) != {"claude", "codex"}
                or contract.get("session_aliases") != CANONICAL_ALIASES
                or contract.get("compatibility", {}).get("hermes_adapter", {}).get("kind") != "bounded-aemeth-home"
            ):
                raise ValueError("contract must be the canonical aemeth-sprint.v1 contract with stable aliases, receipt schema, and Hermes Aemeth adapter")
        raw = json.loads(topology_path.read_text(encoding="utf-8"))
        receipt = InvokeTrailblazer(NewAemethSprint(raw))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        blocked_receipt = {
            "schema_version": "trailblazer-run-receipt.v1",
            "status": "BLOCKED",
            "blocked_at": "topology-validation",
            "problem": str(exc),
        }
        rendered_problem = json.dumps(blocked_receipt, indent=2, sort_keys=True)
        if receipt_path:
            receipt_path.parent.mkdir(parents=True, exist_ok=True)
            receipt_path.write_text(rendered_problem + "\n", encoding="utf-8")
        print(rendered_problem)
        return 1
    rendered = json.dumps(receipt, indent=2, sort_keys=True)
    if receipt_path:
        receipt_path.parent.mkdir(parents=True, exist_ok=True)
        receipt_path.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)
    return 0 if receipt["status"] == "PASS" else 2


if __name__ == "__main__":
    sys.exit(main())
