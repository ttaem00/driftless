from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
import re
from pathlib import Path, PurePosixPath, PureWindowsPath
from typing import Any

from jsonschema import Draft202012Validator


OUTPUT_FILES = ("manager.html", "llm-context.json", "llm-context.md")
OWNER_FILE = ".wuther-codemap-owner.json"
OWNER_CONTENT = json.dumps(
    {"contract": "wuther-codemap.v1", "owned_files": list(OUTPUT_FILES)},
    ensure_ascii=True,
    sort_keys=True,
    indent=2,
) + "\n"
DEFAULT_SCHEMA = Path(__file__).resolve().parents[2] / "schemas" / "wuther-codemap.schema.json"
HIDDEN_HOME_PATTERN = "|".join(
    re.escape("." + name) for name in ("s" + "sh", "co" + "dex", "clau" + "de", "her" + "mes")
)
PRIVATE_TEXT_PATTERNS = (
    re.compile(r"(?i)(?:^|[\s(])(?:[a-z]:[\\/]|\\\\|/users/|/home/|~/\.)"),
    re.compile(r"(?i)(?:^|[\\/])(?:" + HIDDEN_HOME_PATTERN + r")(?:[\\/]|$)"),
    re.compile(r"(?i)\.runtime[\\/](?:codex|claude|hermes)-home"),
    re.compile(r"(?i)(?:NID_AUT|NID_SES)"),
    re.compile(r"(?i)(?:api[_-]?key|access[_-]?token|password|cookie)\s*[:=]\s*\S+"),
)
CANONICAL_SCHEMA_DIGEST = "c9654e6d69494deff87ee2035e5c1fee22c4d4fd00f7c8927b3543ed1b55065c"


def load_manifest(path: Path, schema_path: Path = DEFAULT_SCHEMA) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        manifest = json.load(handle)
    with schema_path.open(encoding="utf-8") as handle:
        schema = json.load(handle)
    semantic_schema = json.dumps(
        schema, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")
    if hashlib.sha256(semantic_schema).hexdigest() != CANONICAL_SCHEMA_DIGEST:
        raise ValueError("schema does not match the canonical wuther-codemap.v1 contract")
    Draft202012Validator.check_schema(schema)
    errors = sorted(Draft202012Validator(schema).iter_errors(manifest), key=lambda item: list(item.path))
    if errors:
        error = errors[0]
        location = ".".join(str(part) for part in error.path) or "<root>"
        raise ValueError(f"schema validation failed at {location}: {error.message}")
    validate_manifest(manifest)
    return manifest


def _require_text(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{label} must be a non-empty string")
    return value.strip()


def _assert_public_safe(value: Any, label: str = "<root>") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            _assert_public_safe(child, f"{label}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            _assert_public_safe(child, f"{label}[{index}]")
    elif isinstance(value, str):
        for pattern in PRIVATE_TEXT_PATTERNS:
            if pattern.search(value):
                raise ValueError(f"{label} contains a private path or secret-like value")


def _require_repo_relative_path(value: Any, label: str) -> str:
    text = _require_text(value, label)
    windows = PureWindowsPath(text)
    posix = PurePosixPath(text.replace("\\", "/"))
    if windows.is_absolute() or posix.is_absolute() or windows.drive:
        raise ValueError(f"{label} must be repository-relative")
    if (
        text.startswith("~")
        or re.match(r"^[A-Za-z][A-Za-z0-9+.-]*:", text)
        or any(part in ("", ".", "..") for part in posix.parts)
    ):
        raise ValueError(f"{label} must not contain a URI or path traversal")
    return text


def validate_manifest(manifest: dict[str, Any]) -> None:
    _assert_public_safe(manifest)
    if manifest.get("schema_version") != "wuther-codemap.v1":
        raise ValueError("schema_version must be wuther-codemap.v1")
    project = manifest.get("project")
    if not isinstance(project, dict):
        raise ValueError("project must be an object")
    for key in ("id", "name", "manager_summary", "source_ref"):
        _require_text(project.get(key), f"project.{key}")

    domains = manifest.get("domains")
    nodes = manifest.get("nodes")
    data_objects = manifest.get("data_objects")
    edges = manifest.get("edges")
    if not all(isinstance(items, list) and items for items in (domains, nodes, data_objects)):
        raise ValueError("domains, nodes, and data_objects must be non-empty arrays")
    if not isinstance(edges, list):
        raise ValueError("edges must be an array")

    domain_ids = {_require_text(item.get("id"), "domains[].id") for item in domains}
    node_ids = {_require_text(item.get("id"), "nodes[].id") for item in nodes}
    data_ids = {_require_text(item.get("id"), "data_objects[].id") for item in data_objects}
    if len(domain_ids) != len(domains) or len(node_ids) != len(nodes) or len(data_ids) != len(data_objects):
        raise ValueError("domain, node, and data object ids must be unique")

    for item in domains:
        for key in ("label", "purpose"):
            _require_text(item.get(key), f"domain {item['id']}.{key}")

    node_inputs: dict[str, set[str]] = {}
    node_outputs: dict[str, set[str]] = {}
    required_manager = ("title", "purpose", "operation", "next_action", "failure_impact")
    for node in nodes:
        if node.get("domain_id") not in domain_ids:
            raise ValueError(f"node {node['id']} references an unknown domain")
        manager = node.get("manager")
        if not isinstance(manager, dict):
            raise ValueError(f"node {node['id']}.manager must be an object")
        for key in required_manager:
            _require_text(manager.get(key), f"node {node['id']}.manager.{key}")
        for key in ("data_in", "data_out"):
            values = node.get(key, [])
            if not isinstance(values, list) or any(value not in data_ids for value in values):
                raise ValueError(f"node {node['id']}.{key} contains an unknown data id")
        node_inputs[node["id"]] = set(node.get("data_in", []))
        node_outputs[node["id"]] = set(node.get("data_out", []))
        refs = node.get("code_refs", [])
        if not isinstance(refs, list) or not refs:
            raise ValueError(f"node {node['id']} must include code_refs")
        for ref in refs:
            _require_repo_relative_path(ref.get("path"), f"node {node['id']} code_ref.path")
            _require_text(ref.get("symbol"), f"node {node['id']} code_ref.symbol")
        risks = node.get("risks")
        if not isinstance(risks, list) or not risks:
            raise ValueError(f"node {node['id']}.risks must be a non-empty array")
        for index, risk in enumerate(risks):
            _require_text(risk, f"node {node['id']}.risks[{index}]")
        _require_text(node.get("validation"), f"node {node['id']}.validation")

    required_data = (
        "manager_name", "description", "form", "type", "safe_example", "origin",
        "created_by", "storage", "validation", "missing_impact", "sensitivity",
    )
    for item in data_objects:
        for key in required_data:
            if key == "safe_example":
                if key not in item:
                    raise ValueError(f"data object {item['id']}.safe_example is required")
            else:
                _require_text(item.get(key), f"data object {item['id']}.{key}")
        if not isinstance(item.get("fields"), list):
            raise ValueError(f"data object {item['id']}.fields must be an array")
        for index, field in enumerate(item["fields"]):
            for key in ("name", "type", "meaning"):
                _require_text(field.get(key), f"data object {item['id']}.fields[{index}].{key}")
        for key in ("transformations", "consumers", "artifacts"):
            if not isinstance(item.get(key, []), list):
                raise ValueError(f"data object {item['id']}.{key} must be an array")

    adjacency = {node_id: [] for node_id in node_ids}
    indegree = {node_id: 0 for node_id in node_ids}
    for edge in edges:
        edge_id = _require_text(edge.get("id"), "edges[].id")
        source = edge.get("from")
        target = edge.get("to")
        data_id = edge.get("data_id")
        if source not in node_ids or target not in node_ids or data_id not in data_ids:
            raise ValueError(f"edge {edge_id} references an unknown node or data object")
        if data_id not in node_outputs[source]:
            raise ValueError(f"edge {edge_id} data_id is not declared by source data_out")
        if data_id not in node_inputs[target]:
            raise ValueError(f"edge {edge_id} data_id is not declared by target data_in")
        _require_text(edge.get("label"), f"edge {edge_id}.label")
        _require_text(edge.get("transform"), f"edge {edge_id}.transform")
        adjacency[source].append(target)
        indegree[target] += 1

    queue = sorted(node_id for node_id, degree in indegree.items() if degree == 0)
    visited = 0
    while queue:
        current = queue.pop(0)
        visited += 1
        for target in sorted(adjacency[current]):
            indegree[target] -= 1
            if indegree[target] == 0:
                queue.append(target)
                queue.sort()
    if visited != len(node_ids):
        raise ValueError("node edges must form an acyclic flow")


def resolve_under_root(path: Path, root: Path, label: str, *, allow_root: bool = False) -> Path:
    root = root.resolve(strict=True)
    candidate = path if path.is_absolute() else root / path
    nearest = candidate
    while not nearest.exists() and nearest != nearest.parent:
        nearest = nearest.parent
    resolved_nearest = nearest.resolve(strict=True)
    resolved = resolved_nearest.joinpath(*candidate.parts[len(nearest.parts):])
    try:
        common = Path(os.path.commonpath((str(root), str(resolved))))
    except ValueError as exc:
        raise ValueError(f"{label} must stay under root") from exc
    if os.name == "nt":
        inside = os.path.normcase(str(common)) == os.path.normcase(str(root))
        same = os.path.normcase(str(resolved)) == os.path.normcase(str(root))
    else:
        inside = common == root
        same = resolved == root
    if not inside or (same and not allow_root):
        raise ValueError(f"{label} must be a child path under root")
    current = root
    for part in resolved.relative_to(root).parts:
        current = current / part
        if current.exists() and (current.is_symlink() or (hasattr(os.path, "isjunction") and os.path.isjunction(current))):
            raise ValueError(f"{label} must not traverse a symlink or junction: {current}")
    return resolved


def assert_owned_artifact(path: Path) -> None:
    if path.exists() and (path.is_symlink() or (hasattr(os.path, "isjunction") and os.path.isjunction(path))):
        raise ValueError(f"generated artifact must not be a symlink or junction: {path}")


def assert_output_ownership(output_dir: Path, *, check: bool) -> None:
    marker = output_dir / OWNER_FILE
    assert_owned_artifact(marker)
    if not output_dir.exists():
        if check:
            raise ValueError("output directory does not exist")
        return
    children = list(output_dir.iterdir())
    if children and not marker.is_file():
        raise ValueError("output directory is not Wuther-owned; choose an empty or marked directory")
    if marker.is_file() and marker.read_text(encoding="utf-8") != OWNER_CONTENT:
        raise ValueError("output ownership marker is invalid")


def build_llm_context(manifest: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema_version": manifest["schema_version"],
        "project": manifest["project"],
        "agent_contract": {
            "before_change": [
                "Declare affected node ids and data object ids.",
                "Read every referenced code location in the selected source ref.",
                "Describe changes to producers, transformations, consumers, storage, and validation.",
            ],
            "after_change": [
                "Update the manifest before claiming the map is current.",
                "Regenerate all outputs and run the deterministic check.",
                "Use a real product path before claiming behavioral completion.",
            ],
        },
        "domains": manifest["domains"],
        "nodes": manifest["nodes"],
        "data_objects": manifest["data_objects"],
        "edges": manifest["edges"],
        "views": manifest.get("views", []),
    }


def build_llm_markdown(context: dict[str, Any]) -> str:
    lines = [
        f"# {context['project']['name']} - Wuther Codemap",
        "",
        context["project"]["manager_summary"],
        "",
        f"Source ref: `{context['project']['source_ref']}`",
        "",
        "## Change contract",
        "",
    ]
    lines.extend(f"- {item}" for item in context["agent_contract"]["before_change"])
    lines.extend(["", "## Flow nodes", ""])
    data_by_id = {item["id"]: item for item in context["data_objects"]}
    for node in context["nodes"]:
        refs = ", ".join(f"`{ref['path']}::{ref['symbol']}`" for ref in node["code_refs"])
        inputs = ", ".join(data_by_id[item]["manager_name"] for item in node.get("data_in", [])) or "None"
        outputs = ", ".join(data_by_id[item]["manager_name"] for item in node.get("data_out", [])) or "None"
        lines.extend([
            f"### {node['id']} - {node['manager']['title']}",
            f"- Purpose: {node['manager']['purpose']}",
            f"- Input: {inputs}",
            f"- Output: {outputs}",
            f"- Code: {refs}",
            f"- Risks: {'; '.join(node['risks'])}",
            f"- Validation: {node['validation']}",
            "",
        ])
    lines.extend(["## Data objects", ""])
    for item in context["data_objects"]:
        lines.extend([
            f"### {item['id']} - {item['manager_name']}",
            f"- Shape: {item['form']} / `{item['type']}`",
            f"- Origin: {item['origin']}",
            f"- Created by: {item['created_by']}",
            f"- Storage: {item['storage']}",
            f"- Validation: {item['validation']}",
            f"- Missing impact: {item['missing_impact']}",
            "",
        ])
    return "\n".join(lines).rstrip() + "\n"


def build_manager_html(manifest: dict[str, Any]) -> str:
    payload = json.dumps(manifest, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    title = html.escape(manifest["project"]["name"])
    summary = html.escape(manifest["project"]["manager_summary"])
    source_ref = html.escape(manifest["project"]["source_ref"])
    return f"""<!doctype html>
<html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title} - Wuther Codemap</title>
<style>
:root{{--bg:#f7f7f5;--surface:#fff;--line:#dddcd7;--text:#20201e;--muted:#65645f;--accent:#4f46c8;--data:#1d659b;--soft:#f0f0ec}}
*{{box-sizing:border-box}} body{{margin:0;background:var(--bg);color:var(--text);font:15px/1.55 system-ui,-apple-system,"Segoe UI",sans-serif;letter-spacing:0}}
button{{font:inherit}} header{{height:76px;padding:14px 24px;background:var(--surface);border-bottom:1px solid var(--line);display:flex;align-items:center;justify-content:space-between;gap:24px}}
h1{{font-size:22px;margin:0}} .subtitle{{color:var(--muted);margin-top:2px}} .source{{font:12px ui-monospace,monospace;color:var(--muted)}}
.layout{{display:grid;grid-template-columns:200px minmax(620px,1fr) 340px;height:calc(100vh - 76px)}} nav{{padding:18px 12px;border-right:1px solid var(--line);background:var(--surface)}}
nav button{{width:100%;border:0;background:transparent;text-align:left;padding:10px 12px;margin:2px 0;border-radius:6px;cursor:pointer}} nav button[aria-selected="true"]{{background:#eeecff;color:#3328a0;font-weight:700}}
main{{padding:22px 26px;overflow:auto}} aside{{border-left:1px solid var(--line);background:var(--surface);padding:22px;overflow:auto}}
.view{{display:none}} .view.active{{display:block}} h2{{font-size:19px;margin:0 0 6px}} h3{{font-size:15px;margin:0 0 6px}} .lead{{color:var(--muted);margin:0 0 20px}}
.node-grid{{display:grid;grid-template-columns:repeat(2,minmax(230px,1fr));align-items:stretch;gap:14px;padding:14px 4px}} .node{{width:250px;min-height:154px;border:1px solid var(--line);border-left:4px solid var(--accent);border-radius:7px;background:var(--surface);padding:14px;text-align:left;position:relative;cursor:pointer}} .node-grid .node{{width:100%}}
.node small{{display:block;color:var(--accent);font-weight:700}} .node strong{{display:block;margin:5px 0 8px}} .node p{{margin:0;color:var(--muted);display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden}}
.edge-list{{display:grid;gap:12px;padding:14px 4px}} .edge-row{{display:grid;grid-template-columns:230px minmax(150px,1fr) 230px;align-items:center;gap:12px}} .edge-arrow{{text-align:center;color:var(--data);font-size:13px}} .edge-arrow strong{{display:block;font-size:20px}} .edge-row .node{{width:230px;min-height:112px}}
.counts{{margin-top:10px;font-size:12px;color:var(--data)}} .grid{{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}} .row{{border-top:1px solid var(--line);padding:12px 0}}
.data-button{{width:100%;text-align:left;border:1px solid var(--line);background:var(--surface);border-radius:7px;padding:13px;cursor:pointer;min-height:106px}} .data-button strong,.data-button span{{display:block}} .data-button span{{color:var(--muted);margin-top:4px}}
.tag{{display:inline-block!important;width:auto;border:1px solid var(--line);border-radius:999px;padding:1px 7px;margin:6px 4px 0 0;font-size:12px;color:var(--muted)}} dl{{margin:0}} dt{{font-size:12px;color:var(--muted);margin-top:15px}} dd{{margin:3px 0 0;overflow-wrap:anywhere}} pre{{white-space:pre-wrap;background:var(--soft);border-radius:6px;padding:10px;font:12px/1.5 ui-monospace,monospace;overflow:auto}}
.empty{{color:var(--muted)}} :focus-visible{{outline:3px solid rgba(79,70,200,.3);outline-offset:2px}}
</style></head><body>
<header><div><h1>Wuther Codemap · {title}</h1><div class="subtitle">{summary}</div></div><div class="source">기준: {source_ref}</div></header>
<div class="layout"><nav aria-label="지도 보기">
<button data-view="easy" aria-selected="true">쉬운 모드</button><button data-view="flow">데이터 흐름</button><button data-view="data">데이터 목록</button><button data-view="domains">분야·모듈</button><button data-view="connections">연결 분석</button>
</nav><main><section id="easy" class="view active"></section><section id="flow" class="view"></section><section id="data" class="view"></section><section id="domains" class="view"></section><section id="connections" class="view"></section></main><aside id="detail" aria-live="polite"></aside></div>
<script>const MODEL={payload};
const byId=(a)=>Object.fromEntries(a.map(x=>[x.id,x])); const nodes=byId(MODEL.nodes), data=byId(MODEL.data_objects), domains=byId(MODEL.domains);
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({{'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}}[c]));
function dataNames(ids){{return (ids||[]).map(id=>data[id]?.manager_name||id).join(', ')||'없음'}}
function nodeCard(n){{return `<button class="node" data-node="${{esc(n.id)}}"><small>${{esc(domains[n.domain_id]?.label)}}</small><strong>${{esc(n.manager.title)}}</strong><p>${{esc(n.manager.purpose)}}</p><span class="counts">받는 정보 ${{n.data_in.length}}종 · 만드는 결과 ${{n.data_out.length}}종</span></button>`}}
function showNode(n){{detail.innerHTML=`<h2>${{esc(n.manager.title)}}</h2><p class="lead">${{esc(n.manager.purpose)}}</p><dl><dt>받는 데이터</dt><dd>${{esc(dataNames(n.data_in))}}</dd><dt>하는 일</dt><dd>${{esc(n.manager.operation)}}</dd><dt>만드는 데이터</dt><dd>${{esc(dataNames(n.data_out))}}</dd><dt>실패하면</dt><dd>${{esc(n.manager.failure_impact)}}</dd><dt>위험</dt><dd>${{esc(n.risks.join(' · '))}}</dd><dt>검증 방법</dt><dd>${{esc(n.validation)}}</dd><dt>관리자가 확인할 일</dt><dd>${{esc(n.manager.next_action)}}</dd><dt>개발자 위치</dt><dd>${{n.code_refs.map(r=>`<code>${{esc(r.path)}}::${{esc(r.symbol)}}${{r.line?':'+r.line:''}}</code>`).join('<br>')}}</dd></dl>`}}
function showData(d){{detail.innerHTML=`<h2>${{esc(d.manager_name)}}</h2><p class="lead">${{esc(d.description)}}</p><dl><dt>데이터 형식</dt><dd>${{esc(d.form)}} · <code>${{esc(d.type)}}</code></dd><dt>주요 항목</dt><dd>${{(d.fields||[]).map(f=>`<span class="tag">${{esc(f.name)}}: ${{esc(f.type)}}</span>`).join('')||'고정 항목 없음'}}</dd><dt>안전한 예시</dt><dd><pre>${{esc(JSON.stringify(d.safe_example,null,2))}}</pre></dd><dt>어디서 생기나</dt><dd>${{esc(d.origin)}}</dd><dt>누가 만드나</dt><dd>${{esc(d.created_by)}}</dd><dt>어떻게 바뀌나</dt><dd>${{esc((d.transformations||[]).join(' → ')||'그대로 전달')}}</dd><dt>어디에 남나</dt><dd>${{esc(d.storage)}}</dd><dt>누가 쓰나</dt><dd>${{esc((d.consumers||[]).join(', ')||'최종 결과')}}</dd><dt>검사 방법</dt><dd>${{esc(d.validation)}}</dd><dt>없으면 생기는 일</dt><dd>${{esc(d.missing_impact)}}</dd></dl>`}}
const cards=MODEL.nodes.map(nodeCard).join('');
const edgeRows=MODEL.edges.map(e=>`<div class="edge-row">${{nodeCard(nodes[e.from])}}<div class="edge-arrow"><strong>→</strong>${{esc(data[e.data_id].manager_name)}}<br>${{esc(e.transform)}}</div>${{nodeCard(nodes[e.to])}}</div>`).join('');
easy.innerHTML=`<h2>처음 보는 프로젝트도 데이터 기준으로 읽습니다</h2><p class="lead">분야별 단계부터 보고, 궁금한 단계를 누르면 받는 데이터와 만드는 데이터를 확인할 수 있습니다.</p><div class="node-grid">${{cards}}</div>`;
document.getElementById('flow').innerHTML=`<h2>데이터가 만들어지는 순서</h2><p class="lead">아래 화살표는 등록된 데이터 edge만 표시합니다. 같은 단계가 여러 연결에 나타날 수 있습니다.</p><div class="edge-list">${{edgeRows||'<p class="empty">등록된 데이터 연결이 없습니다.</p>'}}</div>`;
document.getElementById('data').innerHTML=`<h2>데이터 목록</h2><p class="lead">파일명보다 내용과 쓰임을 먼저 봅니다.</p><div class="grid">${{MODEL.data_objects.map(d=>`<button class="data-button" data-data="${{esc(d.id)}}"><strong>${{esc(d.manager_name)}}</strong><span>${{esc(d.description)}}</span><span class="tag">${{esc(d.form)}}</span><span class="tag">${{esc(d.sensitivity)}}</span></button>`).join('')}}</div>`;
document.getElementById('domains').innerHTML=`<h2>분야·모듈</h2><p class="lead">같은 목적의 코드를 묶어서 봅니다.</p>${{MODEL.domains.map(d=>`<div class="row"><h3>${{esc(d.icon||'▣')}} ${{esc(d.label)}}</h3><div>${{esc(d.purpose)}}</div><div class="counts">${{MODEL.nodes.filter(n=>n.domain_id===d.id).map(n=>esc(n.manager.title)).join(' · ')}}</div></div>`).join('')}}`;
document.getElementById('connections').innerHTML=`<h2>연결 분석</h2><p class="lead">어떤 단계가 어떤 데이터를 넘기는지 확인합니다.</p>${{MODEL.edges.map(e=>`<div class="row"><strong>${{esc(nodes[e.from].manager.title)}} → ${{esc(nodes[e.to].manager.title)}}</strong><div>${{esc(data[e.data_id].manager_name)}} · ${{esc(e.transform)}}</div></div>`).join('')}}`;
detail.innerHTML='<h2>선택한 내용</h2><p class="lead">단계나 데이터를 누르면 형식, 생성 위치, 변화, 저장 위치와 누락 영향을 보여줍니다.</p>';
document.addEventListener('click',e=>{{const nb=e.target.closest('[data-node]'),db=e.target.closest('[data-data]');if(nb)showNode(nodes[nb.dataset.node]);if(db)showData(data[db.dataset.data]);const vb=e.target.closest('[data-view]');if(vb){{document.querySelectorAll('[data-view]').forEach(b=>b.setAttribute('aria-selected',String(b===vb)));document.querySelectorAll('.view').forEach(v=>v.classList.toggle('active',v.id===vb.dataset.view));}}}});
</script></body></html>"""


def build_outputs(manifest: dict[str, Any]) -> dict[str, str]:
    context = build_llm_context(manifest)
    return {
        "manager.html": build_manager_html(manifest),
        "llm-context.json": json.dumps(context, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        "llm-context.md": build_llm_markdown(context),
    }


def atomic_write(path: Path, content: str) -> None:
    assert_owned_artifact(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(f".{path.name}.tmp")
    try:
        temp.write_text(content, encoding="utf-8", newline="\n")
        os.replace(temp, path)
    finally:
        if temp.exists():
            temp.unlink()


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Wuther Codemap manager and LLM views")
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--clean", action="store_true")
    parser.add_argument("--clean-only", action="store_true")
    args = parser.parse_args()
    if args.check and (args.clean or args.clean_only):
        raise ValueError("--check cannot be combined with cleanup")

    root = args.root.resolve(strict=True)
    manifest_path = resolve_under_root(args.manifest, root, "manifest")
    output_dir = resolve_under_root(args.output_dir, root, "output directory")
    try:
        schema_path = resolve_under_root(args.schema, root, "schema")
    except ValueError:
        package_root = Path(__file__).resolve().parents[2]
        schema_path = resolve_under_root(args.schema, package_root, "schema")
    if manifest_path.is_relative_to(output_dir):
        raise ValueError("output directory must not contain the manifest")
    for name in OUTPUT_FILES:
        assert_owned_artifact(output_dir / name)
    assert_output_ownership(output_dir, check=args.check)

    if args.clean_only:
        for name in OUTPUT_FILES:
            path = output_dir / name
            if path.exists():
                path.unlink()
        return 0

    outputs = build_outputs(load_manifest(manifest_path, schema_path))
    if args.clean:
        for name in OUTPUT_FILES:
            path = output_dir / name
            if path.exists():
                path.unlink()
    if args.check:
        expected = {**outputs, OWNER_FILE: OWNER_CONTENT}
        stale = [name for name, content in expected.items() if not (output_dir / name).is_file() or (output_dir / name).read_text(encoding="utf-8") != content]
        if stale:
            print("STALE: " + ", ".join(stale))
            return 1
        print("WUTHER_CODEMAP_CHECK_PASS")
        return 0

    for name, content in outputs.items():
        atomic_write(output_dir / name, content)
    atomic_write(output_dir / OWNER_FILE, OWNER_CONTENT)
    print("WUTHER_CODEMAP_GENERATED " + ", ".join(OUTPUT_FILES))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
