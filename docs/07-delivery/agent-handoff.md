# Agent Handoff Guide - Dojo MVP

This is the operational handoff doc for implementation agents.

Authoritative sources:
- `docs/02-spec/mvp-functional-spec.md`
- `docs/02-spec/design-decisions.md`
- `docs/07-delivery/dojo-mvp-prd.md`
- `docs/07-delivery/dojo-mvp-implementation-checklist.md`

If this file conflicts with other docs, follow the two `docs/02-spec/*` files first.

Canonical workspace path for implementation is `game/`.

## 1. Mandatory Read Order (Before Coding)

1. `docs/02-spec/design-decisions.md`
2. `docs/02-spec/mvp-functional-spec.md`
3. `docs/07-delivery/dojo-mvp-prd.md`
4. `docs/07-delivery/dojo-mvp-implementation-checklist.md`
5. This file

## 2. Execution Commands

Run from repo root.

Bootstrap:

```bash
pwd
ls -la
```

If game workspace exists:

```bash
cd game
dojo build
dojo test
```

If `game/` is missing or build tooling is unavailable:
- Stop and report blocker.
- Do not invent alternate structure without approval.

Per-change loop:

```bash
# from repo root or game root as appropriate
dojo build
dojo test
```

Minimum required on every PR:
- Build passes.
- Relevant unit tests pass.
- Any changed integration tests pass.

## 3. Branch and PR Rules

Branch naming:
- `feat/m0-<short-scope>`
- `feat/m1-<short-scope>`
- `feat/s1-<short-scope>`
- `fix/<short-scope>`

PR title format:
- `[M0] Shared types and cube codec`
- `[M1] World and area models`
- `[S2] Adventurer manager with permadeath`

PR scoping rules:
- Exactly one stage per PR (`M0`, `M1`, ... `S5`).
- No cross-stage scope creep.
- Keep domain boundaries tight (no god contracts).
- Include tests in same PR as implementation changes.

## 4. Required PR Output Format

Every agent PR/update must include this exact structure:

```text
Stage: <M0|M1|M2|M3|M4|S1|S2|S3|S4|S5>
Scope: <one sentence>

Changed Files:
- <path>
- <path>

What Was Implemented:
1. ...
2. ...

Tests Run:
- <command>
- <command>

Test Results:
- Passed: <list>
- Failed: <list or none>

Spec/Decision Mapping:
- Spec section(s): <refs>
- Decision(s): <DD-00x>

Risks/Follow-ups:
- ...
```

## 5. Stop and Escalation Rules

Agents must stop and ask for clarification when:
- A required decision is not locked in `docs/02-spec/design-decisions.md`.
- Requested change conflicts with locked decisions.
- A change requires expanding MVP scope.
- `game/` workspace is missing or cannot build/test.
- A fix requires touching multiple stages in one PR.
- Toolchain errors prevent confidence in results.

Agents may proceed without asking only when:
- Change is inside a single active stage.
- It is fully aligned with locked decisions.
- Build + tests can validate behavior.

## 6. Ownership Boundaries for Parallel Agents

Use one active owner per stage.

Recommended parallel lanes:
- Agent A: `M0/M1` foundation (`libs`, `models/world`, world tests)
- Agent B: `M2` adventurer/inventory/death models and tests
- Agent C: `M3` harvesting models/math and tests
- Agent D: `M4` economics/ownership models/math and tests
- Agent E: Systems (`S1-S5`) only after corresponding model stage is merged

Hard boundary rules:
- Do not modify another agent's stage files without explicit handoff.
- Shared files (`lib.cairo`, `models/mod.cairo`, `events/mod.cairo`) require merge coordination note.
- If overlap is unavoidable, rebase and post conflict-resolution summary in PR.

## 7. Handoff Protocol Between Agents

When handing off a stage:
- Mark stage checklist items complete in PR description.
- Reference exact exit gate from `dojo-mvp-implementation-checklist.md`.
- Provide passing command output summary (not raw logs only).
- State next unlocked stage for downstream agent.

## 8. Definition of Ready (Before Starting Any Stage)

- Stage prerequisites merged.
- Stage files and tests identified.
- Decisions mapped.
- No unresolved blockers.

## 9. Definition of Done (Per Stage)

- Stage implementation complete.
- Stage unit tests pass.
- Relevant integration tests pass (if impacted).
- Spec/decision mapping included in PR.
- No contract-boundary violations introduced.
