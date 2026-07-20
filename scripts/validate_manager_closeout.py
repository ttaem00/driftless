#!/usr/bin/env python3
"""Validate bounded sprint, manager audit, durable evidence, and skill evolution records."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import re
import sys
from pathlib import Path


class ValidationError(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def validate_sprint(data: dict) -> None:
    required = {"goal", "target_minutes", "contingency_minutes", "hard_stop_minutes", "scope_in", "scope_out", "proof_rows", "checkpoints", "state"}
    require(required <= data.keys(), "missing sprint fields")
    target, contingency, hard_stop = (data[k] for k in ("target_minutes", "contingency_minutes", "hard_stop_minutes"))
    require(0 < target <= contingency <= hard_stop, "invalid timebox ordering")
    require(set(data["scope_in"]).isdisjoint(data["scope_out"]), "scope_in and scope_out overlap")
    require(data["state"] in {"SCOPE_LOCKED", "RUNNING", "VERIFYING", "MANAGER_AUDIT", "DONE", "STOPPED"}, "invalid sprint state")
    require(all(0 < item["at_minutes"] < hard_stop for item in data["checkpoints"]), "checkpoint outside hard stop")
    require(len(data["proof_rows"]) > 0, "at least one proof row is required")
    if data["state"] == "DONE":
        require(all(row.get("status") == "PASS" for row in data["proof_rows"]), "DONE requires every proof row PASS")
        require(data.get("manager_audit_status") == "PASS", "DONE requires manager audit PASS")
    if data["state"] == "STOPPED":
        require(bool(data.get("next_action")), "STOPPED requires next_action")


def validate_audit(data: dict) -> None:
    categories = data.get("audited_categories", [])
    require(len(categories) >= 12 and len(categories) == len(set(categories)), "audit requires at least 12 unique categories")
    valid_status = {"PASS", "FINDING", "NOT_APPLICABLE", "UNVERIFIED"}
    require(all(item.get("status") in valid_status and item.get("evidence") for item in data.get("results", [])), "invalid audit result")
    require({item.get("category") for item in data.get("results", [])} == set(categories), "every audited category needs one result")
    for finding in data.get("findings", []):
        require(finding.get("classification") in {"blocker", "warning", "backlog", "rejected", "out_of_scope"}, "invalid finding classification")
        require(bool(finding.get("direct_goal_impact")), "finding needs direct_goal_impact")
        require(not (finding.get("classification") == "blocker" and finding.get("excluded")), "excluded work cannot be a blocker")


PATH_PATTERNS = [
    re.compile(r"(?i)(?:[a-z]:\\|/home/|/users/)[^\s\"']+"),
    re.compile(r"codex://threads/[0-9a-f-]+", re.I),
]
SECRET_PATTERN = re.compile(r"(?i)(?:api[_-]?key|secret|token|password)\s*[:=]\s*[^\s,}]+")


def scan_text(text: str, location: str) -> list[str]:
    failures = []
    for pattern in PATH_PATTERNS:
        if pattern.search(text):
            failures.append(f"unsafe locator at {location}")
    if SECRET_PATTERN.search(text):
        failures.append(f"secret-shaped content at {location}")
    return failures


def validate_evidence(data: dict) -> None:
    require(bool(data.get("source_revision")), "source_revision is required")
    require(bool(data.get("reproduce_command")), "reproduce_command is required")
    failures = scan_text(json.dumps({k: v for k, v in data.items() if k != "files"}), "bundle")
    digest_rows = []
    for index, item in enumerate(data.get("files", [])):
        path = item.get("path", "")
        require(path and not Path(path).is_absolute() and not re.match(r"^[A-Za-z]:", path), "evidence path must be relative")
        try:
            raw = base64.b64decode(item.get("content_base64", ""), validate=True)
            text = raw.decode("utf-8")
        except Exception as exc:
            raise ValidationError(f"invalid base64/utf-8 at files[{index}]") from exc
        actual = hashlib.sha256(raw).hexdigest()
        require(actual == item.get("sha256"), f"sha256 mismatch at files[{index}]")
        failures.extend(scan_text(text, f"files[{index}].content_base64"))
        digest_rows.append(f"{path}:{actual}")
    require(digest_rows, "evidence bundle needs at least one file")
    expected = hashlib.sha256((data["source_revision"] + "\n" + "\n".join(digest_rows)).encode()).hexdigest()
    require(expected == data.get("bundle_digest"), "bundle_digest mismatch")
    require(not failures, "; ".join(failures))


def validate_evolution(data: dict) -> None:
    decisions = {"update_existing", "thin_wrapper", "create_new", "script_or_gate", "record_only", "no_change"}
    require(data.get("decision") in decisions, "invalid evolution decision")
    require(bool(data.get("root_cause_class")) and bool(data.get("placement")), "root cause and placement are required")
    assets = data.get("existing_assets_considered", [])
    require(len(assets) >= 2, "at least two existing assets must be considered")
    if data["decision"] == "create_new":
        require(bool(data.get("unique_trigger")) and bool(data.get("unique_output")) and bool(data.get("second_use_case")), "create_new requires unique trigger, output, and second use case")
    require(data.get("validation", {}).get("status") == "PASS", "skill evolution requires validation PASS")
    require(bool(data.get("expected_saving")) and bool(data.get("optimization_applied")), "optimization fields are required")


VALIDATORS = {"sprint": validate_sprint, "audit": validate_audit, "evidence": validate_evidence, "evolution": validate_evolution}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--kind", choices=sorted(VALIDATORS), required=True)
    parser.add_argument("--input", type=Path, required=True)
    args = parser.parse_args()
    try:
        data = json.loads(args.input.read_text(encoding="utf-8"))
        require(isinstance(data, dict), "root must be an object")
        VALIDATORS[args.kind](data)
    except (OSError, json.JSONDecodeError, ValidationError) as exc:
        print(f"FAIL: {exc}")
        return 1
    print(f"PASS: {args.kind}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
