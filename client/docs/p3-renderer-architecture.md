# P3 Renderer Architecture Notes

Status: Draft  
Last updated: 2026-02-16

## Scope

This note documents the deterministic renderer contracts used by `@gen-dungeon/explorer-renderer-webgl` for P3:
- pass order
- shader/symbol constants
- fixture scene setup used in snapshot and picking tests

Implementation references:
- `packages/explorer-renderer-webgl/src/render-constants.ts`
- `packages/explorer-renderer-webgl/src/draw-batching.ts`
- `packages/explorer-renderer-webgl/src/draw-pipeline.ts`
- `packages/explorer-renderer-webgl/src/culling.ts`
- `packages/explorer-renderer-webgl/src/picking.ts`

## Pass Order Contract

`DRAW_PASS_ORDER` is fixed and deterministic:
1. `grid`
2. `hex`
3. `overlay`
4. `glyph`

`draw-batching.ts` batches commands by `(pass, shaderKey, symbol)` after pass-order sorting.  
This keeps state transitions grouped without changing snapshot/picking semantics.

## Shader Contracts

`SHADER_KEYS` is centralized in `render-constants.ts`:
- `grid -> grid-lines-v1`
- `hex -> hex-fill-v1`
- `overlay -> overlay-symbol-v1`
- `glyph -> glyph-atlas-v1`

Current tests assert deterministic draw-command snapshots, not GPU framebuffers.  
When WebGL shader programs are wired, these keys are the stable binding contract.

## Symbol Contracts

Claim overlay symbols:
- active claim: `C`
- claimable: `!`
- idle: `.`

Claim glyph symbols:
- active claim: `CLM`
- claimable: `ALR`
- idle: `DOT`

Biome glyphs currently pinned for fixtures:
- `Plains -> PLN`
- `Forest -> FOR`
- `Desert -> DES`

## Fixture Scene Setup

Current deterministic fixtures are defined in renderer tests:
- `tests/camera.red.test.ts`: top-down pan/zoom constraints and transform round-trips.
- `tests/culling.red.test.ts`: visible chunk selection plus one-ring prefetch assembly.
- `tests/picking.red.test.ts`: offscreen ID buffer decode for pointer/touch hit-tests.
- `tests/overlay-glyph.red.test.ts`: draw-pass snapshot assertions for biome/claim overlays and glyph atlas encoding.

All fixture inputs are pure data (`ChunkSnapshot`, ID-buffer bytes), so snapshots are runtime-stable.

## Validation

Run from `client/`:

```bash
bun run typecheck
bun run test
```
