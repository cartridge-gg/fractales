# Multi-Agent Coordination — FRACTALES

<roles>

| Role | Agent | Responsibility | Does NOT |
|------|-------|----------------|----------|
| Coordinator | Main context | Plans, delegates, tracks progress, synthesizes results | Write implementation code |
| Contract Dev | kraken/spark | Implements Cairo systems, models, libs, tests | Make architectural decisions, touch client |
| Client Dev | kraken/spark | Implements TypeScript explorer packages | Touch Cairo contracts |
| Reviewer | critic/judge | Validates code quality, spec alignment, test coverage | Implement features |
| Researcher | scout/oracle | Explores codebase, external docs, Dojo/Starknet APIs | Write code |
| Deployer | Skill: gen-dungeon-live-slot-deploy | Slot provisioning, migration, verification | Modify contract logic |

</roles>

<ownership_boundaries>

### Contract stages (from agent-handoff.md)
- **M0/M1**: Foundation — `libs/`, `models/world`, world tests
- **M2**: Adventurer — `models/adventurer`, `models/inventory`, `models/deaths`
- **M3**: Harvesting — `models/harvesting`, `libs/conversion_math`
- **M4**: Economics/Ownership — `models/economics`, `models/ownership`, `libs/decay_math`
- **S1-S5**: Systems — only after corresponding model stage is merged

### Client packages
- `explorer-app` — app shell, UI integration
- `explorer-data` — store, selectors, streaming
- `explorer-proxy-node` — HTTP/WS proxy
- `explorer-renderer-webgl` — WebGL rendering
- `explorer-types` — shared types (coordinate changes need all-package awareness)
- `torii-views` — SQL views (changes affect proxy and data layers)

### Hard rules
- One active owner per stage
- Do not modify another agent's stage files without explicit handoff
- Shared files (`lib.cairo`, `models.cairo`, `events.cairo`) require merge coordination
- Client type changes in `explorer-types` require downstream package verification

</ownership_boundaries>

<parallelization>

### SAFE to parallelize
- Different contract stages (M0 + M2 if no shared file overlap)
- Contract work + client work (different directories)
- Unit test writing + integration test writing (different files)
- Documentation + implementation (different directories)
- Multiple client packages with no type dependency changes

### MUST serialize
- System implementation (S*) after its model stage (M*) merges
- Changes touching `lib.cairo` or module root files
- Slot deployment steps (provision → migrate → init → verify)
- `snforge test` runs (never parallel)
- Client packages when `explorer-types` changes

### Conflict resolution
1. Detect overlapping file changes early via `git diff --name-only`
2. Pause later task
3. Let first task complete and merge
4. Rebase second task
5. Re-verify changes still apply

</parallelization>

<delegation_protocol>

### Investigation phase (main context or scout)
1. Read relevant spec sections (`docs/02-spec/*`)
2. Read target files to understand current state
3. Identify all files that need changes
4. Create detailed implementation plan with file-level scope
5. Estimate complexity (single-file fix vs. multi-file feature)

### Execution phase (kraken/spark)
1. Follow the detailed plan
2. Implement changes within assigned stage boundary
3. Run `snforge test <relevant_filter>` after each logical change
4. Run full `snforge test` before marking complete
5. Report blockers immediately — do not work around spec gaps

</delegation_protocol>

<task_lifecycle>

```
pending → in_progress → in_review → done
                      ↘ blocked
                      ↘ cancelled
```

### Transitions
- `pending → in_progress`: Agent assigned, prerequisites met
- `in_progress → in_review`: Implementation complete, tests passing
- `in_progress → blocked`: Awaiting dependency, spec clarification, or merge
- `in_review → done`: Code reviewed, tests passing, merged

### Definition of Done (per stage)
- Implementation complete within stage boundary
- Unit tests pass: `snforge test <manager_name>`
- Integration tests pass (if impacted)
- Spec/decision mapping documented
- No contract-boundary violations

</task_lifecycle>

<escalation>

Escalate when:
- Blocked >30 minutes without progress
- Decision not locked in `docs/02-spec/design-decisions.md`
- Change conflicts with locked design decisions
- Scope expansion beyond current MVP boundary
- Security implications discovered
- Breaking change to Dojo models (affects indexer state)
- Need to touch shared files across stage boundaries

Format:
```
## Escalation: [Title]
**Stage**: [M0-M4 / S1-S5]
**Blocker**: [description]
**Spec ref**: [section in mvp-functional-spec.md]
**Options**:
1. [Option A] — [trade-offs]
2. [Option B] — [trade-offs]
**Recommendation**: [which and why]
```

</escalation>
