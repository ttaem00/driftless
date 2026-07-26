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


class Aemeth:
    """Data-driven validation gate and feedback policy."""

    def __init__(self, sprint_spec: dict[str, Any]):
        self.required_status = str(sprint_spec.get("required_status", "PASS"))
        self.require_evidence = bool(sprint_spec.get("require_evidence", True))

    def verify(self, step: "Stelle") -> tuple[bool, str]:
        verification = step.verification
        passed = verification.get("status") == self.required_status
        evidence = verification.get("evidence")
        if self.require_evidence and (not isinstance(evidence, str) or not evidence.strip()):
            return False, "verification evidence is missing"
        normalized_evidence = evidence.strip() if isinstance(evidence, str) else "evidence not required"
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
        if not isinstance(exception_contract, dict) or not exception_contract.get("on_failure"):
            raise ValueError(f"step {step_id}: exception.on_failure is required")
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
        if not artifacts or not all(isinstance(item, dict) and item.get("id") for item in artifacts):
            raise ValueError("topology artifacts must contain named objects")
        if not isinstance(boundary, dict) or not isinstance(boundary.get("in_scope"), list) or not isinstance(boundary.get("out_of_scope"), list):
            raise ValueError("topology boundary requires in_scope and out_of_scope arrays")
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
        self.ordered_steps()

    @classmethod
    def from_dict(cls, raw: dict[str, Any]) -> "StarrailTopology":
        if raw.get("schema_version") != "starrail-topology.v1":
            raise ValueError("schema_version must be starrail-topology.v1")
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
            [Stelle.from_dict(item) for item in raw.get("steps", [])],
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


def Trailblazer(topology: StarrailTopology) -> dict[str, Any]:
    """Traverse a topology and stop at the first failed Aemeth gate."""

    rows: list[dict[str, Any]] = []
    completed: set[str] = set()
    status = "PASS"
    blocked_at: str | None = None
    feedback: dict[str, str] | None = None
    gate = Aemeth(topology.aemeth_spec)
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
        "schema_version": "trailblazer-receipt.v1",
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


def main() -> int:
    parser = argparse.ArgumentParser(description="Run a public-safe Starrail evidence sprint.")
    parser.add_argument("--topology", type=Path, required=True)
    parser.add_argument("--contract", type=Path)
    parser.add_argument("--receipt", type=Path)
    args = parser.parse_args()
    try:
        if args.contract:
            contract = json.loads(args.contract.read_text(encoding="utf-8"))
            if contract.get("schema_version") != "starrail-sprint.v1" or set(contract.get("profiles", [])) != {"claude", "codex"}:
                raise ValueError("contract must be the shared starrail-sprint.v1 two-profile contract")
        raw = json.loads(args.topology.read_text(encoding="utf-8"))
        receipt = Trailblazer(StarrailTopology.from_dict(raw))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(json.dumps({"schema_version": "trailblazer-receipt.v1", "status": "ERROR", "problem": str(exc)}, indent=2))
        return 1
    rendered = json.dumps(receipt, indent=2, sort_keys=True)
    if args.receipt:
        args.receipt.parent.mkdir(parents=True, exist_ok=True)
        args.receipt.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)
    return 0 if receipt["status"] == "PASS" else 2


if __name__ == "__main__":
    sys.exit(main())
