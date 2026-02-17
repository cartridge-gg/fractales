# P5 Performance and Reliability Runbook

Status: Active  
Last updated: 2026-02-17  
Owners: Client Platform + Game Infra

## 1. SLO Definitions

Client SLOs:
- Freshness: p95 block-inclusion to on-screen update latency < 2000 ms.
- Mobile performance: baseline exploration >= 30 FPS.
- Reliability: patch-apply queue depth remains bounded (target <= 512) with no unbounded growth over endurance runs.

Proxy/indexing SLOs:
- Chunk query latency p95 within service budget.
- Resync frequency remains below alert threshold for normal traffic windows.

Runtime gate source of truth:
- `scripts/p5-hardening-gate.ts` enforces thresholds and exits non-zero on regressions.
- Default report output: `artifacts/p5-hardening-gate-report.json`.

## 2. Metrics and Dashboards

Required dashboard panels:
- client.avg_fps
- client.p95_frame_time_ms
- client.p95_freshness_latency_ms
- client.patch_queue_depth.max
- client.patch_queue_dropped_ratio
- proxy.chunk_query_latency_ms.p50
- proxy.chunk_query_latency_ms.p95
- proxy.ws_resync_required.count

Recommended dashboard layout:
1. User-visible health: FPS + freshness.
2. Queue/backpressure health: depth + drop ratio + processing throughput.
3. Proxy transport health: chunk latency + resync counts.

## 3. Alert Thresholds

Critical:
- p95 freshness latency >= 2000 ms for 15 minutes.
- mobile-equivalent FPS < 30 for 15 minutes.
- queue depth > 512 sustained for 10 minutes.

Warning:
- drop ratio > 0.20 for 10 minutes.
- resync frequency above baseline envelope for 30 minutes.

## 4. Mitigation Playbook

## 4.1 Freshness Degradation

1. Confirm latest perf-smoke output from CI (`bun run test:perf-smoke`).
2. Check queue depth and drop ratio; if elevated, apply backpressure tuning profile.
3. Verify proxy chunk latency panel for upstream bottlenecks.
4. If unresolved, temporarily reduce render workload by lowering overlay density.

## 4.2 FPS Regression

1. Compare latest and previous perf harness runs in renderer package.
2. Verify culling and instancing profile remained on optimized path.
3. Check glyph atlas batching metrics for command explosion.
4. Roll back recent renderer pass-level changes if regression is acute.

## 4.3 Queue Growth / Reliability Risk

1. Validate queue cap configuration remained enabled.
2. Inspect dropped ratio vs max queue depth trend.
3. If depth climbs toward cap, increase batch throughput or reduce apply interval.
4. If drops breach warning threshold, trigger incident review and patch-rate analysis.

## 5. CI/Validation Commands

Run from `client/`:

```bash
bun run typecheck
bun run test
bun run test:perf-smoke
bun run test:hardening-gate
```

Targeted package smoke:

```bash
bun run --filter @gen-dungeon/explorer-renderer-webgl test:perf
bun run --filter @gen-dungeon/explorer-data test:perf
```

Custom report path:

```bash
bun run test:hardening-gate -- --report=artifacts/custom-hardening-report.json
```

CI workflow:
- `.github/workflows/perf-hardening-gate.yml`
