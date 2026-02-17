<identity>
Infinite Hex Adventurers (FRACTALES) — a headless on-chain game on Starknet where discovery drives ownership and economy. Built with Dojo ECS on Cairo, with a TypeScript explorer client.
</identity>

<stack>

| Layer | Tech | Version | Notes |
|-------|------|---------|-------|
| Contracts | Cairo / Dojo | 1.8.0 | `game/Scarb.toml` |
| Compiler | Scarb | 2.13.1 | CI-pinned |
| Test runner | snforge | 0.51.2 | **Run sequentially — no parallel snforge** |
| Client | TypeScript / Bun | 1.3.1 | Monorepo with workspaces |
| Bundler | Vite | — | explorer-app dev server |
| Test (client) | Vitest | 2.x | `bun run test` from `client/` |
| Indexer | Torii | — | SQL views + GraphQL + WebSocket |
| Chain | Katana (Slot) | — | Deployed via `slot` CLI |
| Migration | sozo | — | `sozo migrate` + `sozo execute` |
| Simulation | Python | 3.x | `game/sim/` economic bootstrap |
| CI | GitHub Actions | — | `.github/workflows/contracts-ci.yml` |

</stack>

<structure>
```
game/                          # Cairo smart contracts (Dojo world)
├── Scarb.toml                 # Package config, scripts, dependencies
├── src/
│   ├── lib.cairo              # Module root — register all modules here
│   ├── systems/               # One *_manager.cairo + *_manager_contract.cairo per domain
│   │   ├── world_manager*          # Hex discovery, area discovery, movement
│   │   ├── adventurer_manager*     # Create, energy, permadeath
│   │   ├── harvesting_manager*     # Init/start/complete/cancel harvest
│   │   ├── economic_manager*       # Conversion, decay, claims, maintenance
│   │   ├── ownership_manager*      # Area ownership, transfers
│   │   ├── mining_manager*         # Mine init, shifts, collapse
│   │   ├── construction_manager*   # Build, upgrade, upkeep
│   │   ├── sharing_manager*        # ACL policies, grants, share rules
│   │   ├── autoregulator_manager*  # Epoch-gated economic policy
│   │   └── world_gen_manager*      # WorldGenConfig initialization
│   ├── models/                # Dojo ECS models (one file per domain)
│   ├── events/                # Event structs (one file per domain)
│   ├── libs/                  # Pure math/logic (no world state access)
│   │   ├── world_gen.cairo         # Deterministic hex/area/plant generation
│   │   ├── world_rng.cairo         # Seed-based RNG
│   │   ├── biome_profiles.cairo    # 20-biome roster config
│   │   ├── coord_codec.cairo       # Cube-coordinate <-> felt encoding
│   │   ├── adjacency.cairo         # Hex adjacency checks
│   │   ├── decay_math.cairo        # Decay/reserve computation
│   │   ├── conversion_math.cairo   # Item-to-energy rates
│   │   ├── mining_math.cairo       # Mining stress/collapse math
│   │   ├── construction_balance.cairo
│   │   ├── sharing_math.cairo      # Basis-point share distribution
│   │   └── autoregulator_math.cairo
│   └── tests/
│       ├── unit/              # Isolated unit tests per module
│       └── integration/       # Cross-system E2E scenarios
├── sim/                       # Python economic simulator
│   ├── bootstrap_world_sim.py
│   └── tests/
└── scripts/                   # Shell scripts for budget checks, smoke tests

client/                        # TypeScript explorer (Bun monorepo)
├── package.json               # Workspace root — bun workspaces
├── packages/
│   ├── explorer-app/          # Vite app — hex map UI
│   ├── explorer-data/         # Data layer (store, selectors, streaming)
│   ├── explorer-proxy-node/   # Node HTTP/WS proxy to Torii
│   ├── explorer-renderer-webgl/ # WebGL hex renderer
│   ├── explorer-types/        # Shared TypeScript types
│   └── torii-views/           # SQL view definitions for Torii indexer

docs/                          # Extensive project documentation
├── MASTER_DOC.md              # Start here — canonical entrypoint
├── 02-spec/                   # MVP functional spec + design decisions (AUTHORITATIVE)
├── 07-delivery/               # PRDs, checklists, release notes
└── ...

skills/                        # Claude agent skills
├── gen-dungeon-agent-play/    # Runtime game client skill
└── gen-dungeon-live-slot-deploy/ # Slot deployment skill
```
</structure>

<conventions>

### Cairo / Contracts
- **Manager pattern**: Each domain has `<name>_manager.cairo` (logic) + `<name>_manager_contract.cairo` (Dojo system interface)
- **Libs are pure**: Files in `libs/` have no world state access — pure math only
- **Module registration**: Every new module must be added to `game/src/lib.cairo`
- **Dojo namespace**: All contract/model names prefixed with `dojo_starter-`
- **Coordinate encoding**: Use `coord_codec` for hex coordinates — cube coords encoded as felt252
- **Generation is deterministic**: World gen is seed-driven from `WorldGenConfig` — never caller-defined payloads
- **Test naming**: Unit tests = `<module>_test.cairo`, integration = `<module>_integration_test.cairo`, E2E = `e2e_<scenario>.cairo`

### TypeScript / Client
- **Bun only**: Use `bun install`, `bun run`, `bun test` — never npm/yarn
- **Workspace refs**: Cross-package deps use `"workspace:*"`
- **Red tests**: Test files suffixed `.red.test.ts` (TDD red-phase convention)
- **Colocation**: Tests in `tests/` directory alongside `src/`

### Branching / PRs
- Branch: `feat/m<N>-<scope>` or `feat/s<N>-<scope>` or `fix/<scope>`
- PR title: `[M0] Short description` — one stage per PR
- Scope: Never cross stage boundaries in a single PR

</conventions>

<commands>

### Contracts (from `game/`)

| Task | Command | Notes |
|------|---------|-------|
| Build | `sozo build` | Compiles Cairo contracts |
| Test all | `snforge test` | **Run sequentially, never parallel** |
| Test filtered | `snforge test <filter>` | e.g. `snforge test adventurer_manager` |
| Smoke tests | `scarb run smoke` | CI smoke suite |
| Budget check | `scarb run budget-check` | Gas + contract size budgets |
| Migrate (local) | `scarb run migrate` | Build + migrate + init world gen |
| Init world gen | `scarb run init-world-gen` | Seeds the WorldGenConfig |

### Client (from `client/`)

| Task | Command | Notes |
|------|---------|-------|
| Install | `bun install` | Frozen lockfile in CI: `--frozen-lockfile` |
| Typecheck | `bun run typecheck` | `tsc -b` across all packages |
| Test all | `bun run test` | Sequential across packages |
| Test one pkg | `bun run test:<name>` | e.g. `test:explorer-data`, `test:proxy` |
| Dev server | `bun run dev:app` | Vite on port 4173 |
| Perf smoke | `bun run test:perf-smoke` | Renderer + data perf + hardening gate |
| Det. replay | `bun run test:deterministic-replay` | Deterministic replay gate |

### Simulation (from repo root)

| Task | Command |
|------|---------|
| Sim tests | `python3 -m unittest game.sim.tests.test_bootstrap_world_sim` |
| Run sim | `python3 game/sim/bootstrap_world_sim.py --mode code_exact --out-dir /tmp/bootstrap-world-smoke` |

### Deployment

| Task | Command |
|------|---------|
| Deploy Katana | `slot deployments create <project> katana --tier <tier> --config <config>` |
| Deploy Torii | `slot deployments create <project> torii --tier <tier> --config <config>` |
| Migrate on Slot | `sozo migrate --rpc-url <url> --katana-account katana0 --wait` (with gas flags) |
| Describe deploy | `slot deployments describe <project> katana\|torii` |

</commands>

<workflows>

### Adding a new game system
1. Create model in `game/src/models/<domain>.cairo`, register in `models.cairo`
2. Create events in `game/src/events/<domain>_events.cairo`, register in `events.cairo`
3. If pure math needed, add lib in `game/src/libs/<domain>_math.cairo`
4. Create `game/src/systems/<domain>_manager.cairo` (logic) + `<domain>_manager_contract.cairo` (Dojo interface)
5. Register all new modules in `game/src/lib.cairo`
6. Write unit tests in `game/src/tests/unit/<domain>_*_test.cairo`
7. Write integration test in `game/src/tests/integration/<domain>_*_integration_test.cairo`
8. Run `snforge test` to verify

### Modifying existing system logic
1. Read the spec: `docs/02-spec/mvp-functional-spec.md` + `design-decisions.md`
2. Read the target `_manager.cairo` and `_manager_contract.cairo`
3. Implement changes
4. Run relevant tests: `snforge test <manager_name>`
5. Run full suite: `snforge test`

### Client development
1. `cd client && bun install`
2. Make changes in relevant `packages/<name>/src/`
3. Run `bun run typecheck` to verify types
4. Run package tests: `bun run test:<name>`
5. Run full test suite: `bun run test`

### Slot deployment
Use the `gen-dungeon-live-slot-deploy` skill or follow `skills/gen-dungeon-live-slot-deploy/SKILL.md`.

</workflows>

<boundaries>

### DO NOT modify without explicit approval
- `game/Scarb.toml` dependencies or version (affects all builds)
- `.github/workflows/*` (CI configuration)
- `dojo_project.toml` (world configuration)
- `game/vendor/` (vendored dependencies)
- Any `.env*` files or credentials
- Slot deployment configs in production

### DO NOT do
- Run `snforge test` in parallel — always sequential
- Use npm/yarn anywhere — Bun only for client
- Pass caller-defined generation payloads — world gen is deterministic onchain
- Create god contracts — keep domain boundaries tight
- Cross stage boundaries in a single PR
- Modify another agent's stage files without handoff

### GATED (requires human review)
- `sozo migrate` to any Slot deployment
- `slot deployments create/delete`
- Any `sozo execute` against live endpoints
- Changes to `WorldGenConfig` initialization parameters
- Removing or renaming existing Dojo models (breaks indexer state)

</boundaries>

<troubleshooting>

| Problem | Solution |
|---------|----------|
| `snforge test` hangs | Never run parallel — use `snforge test <filter>` for subset |
| `InsufficientResourcesForValidate` on Slot | Increase `--l2-gas` to 15000000000 |
| `Missing latest block number` on Slot | Don't use `--optimistic`; create fresh Katana with `--config` |
| Dojo contract missing WRITER role | `sozo auth grant writer dojo_starter,dojo_starter-<contract>` |
| Build fails after new module | Check `game/src/lib.cairo` — module must be registered |
| Client typecheck fails | Run `bun install` first, then `bun run typecheck` |
| Test file not found by snforge | Ensure test module registered in `lib.cairo` under `tests` |

</troubleshooting>

<docs>
Authoritative reading order:
1. `docs/02-spec/design-decisions.md` — locked design decisions
2. `docs/02-spec/mvp-functional-spec.md` — MVP functional spec (source of truth)
3. `docs/07-delivery/agent-handoff.md` — agent operating contract
4. `docs/MASTER_DOC.md` — full documentation index

If any document conflicts with `docs/02-spec/*`, the spec files win.
</docs>

<live_deployment>
Current live Slot instance (as of 2026-02-13):
- Project: `gen-dungeon-live-20260213b`
- Katana RPC: `https://api.cartridge.gg/x/gen-dungeon-live-20260213b/katana`
- Torii HTTP: `https://api.cartridge.gg/x/gen-dungeon-live-20260213b/torii`
- World: `0x00f3d3b78a41b212442a64218a7f7dbde331813ea09a07067c7ad12f93620c11`
- Release notes: `docs/07-delivery/releases/2026-02-13-gen-dungeon-live-20260213b.md`
</live_deployment>
