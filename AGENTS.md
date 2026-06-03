# Driftless Agent Guidance

Driftless is public OSS for applying shared Claude + Codex agent workflows. Keep
it public-safe, useful to non-developer students and maintainers, and focused on
reducing setup, git/GitHub, security, validation, and raw-script burden.

## Product Identity
- User goal: apply practical agent workflows without becoming a toolchain
  operator.
- Audience: non-developer students and maintainers who need clear setup,
  safety, evidence, and recovery paths.
- Core promise: one public shared tier, two profiles. Shared improvements live
  in `profiles/shared/` once and are consumed by both Claude and Codex profiles.
- Public docs must explain user value. Do not include private campaign notes,
  promotion plans, or internal positioning goals.

## Cross-Runtime Learning
- When maintainers prove an improvement or lesson in real use, evaluate it for
  Driftless before calling the work done.
- Public-safe, tool-agnostic improvements go to `profiles/shared/`.
- Claude-specific improvements go to `profiles/claude/`; Codex-specific
  improvements go to `profiles/codex/`.
- Private, unsafe, account-specific, promotion, or internal strategy material
  must not be copied into the public repo. Record a sanitized follow-up or
  explicit skip reason instead.

## Evidence
- Do not claim an improvement is reflected without command evidence such as
  `rg`, a relevant gate, or a real install/use check.
- Static doc changes do not prove behavior. Behavioral claims need real use or a
  bounded end-to-end test.
