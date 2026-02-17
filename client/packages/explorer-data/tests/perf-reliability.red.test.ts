import { describe, expect, it } from "vitest";
import {
  evaluateFreshnessSlo,
  evaluateReliabilityBudget,
  generatePatchArrivals,
  runPatchPipelineSimulation
} from "../src/perf-reliability.js";

describe("freshness and reliability harness (RED)", () => {
  it("freshness.p95_update_latency_under_2s.red", () => {
    const arrivals = generatePatchArrivals({
      count: 2400,
      baseIntervalMs: 40,
      burstEvery: 120,
      burstSize: 24
    });

    const baseline = runPatchPipelineSimulation({
      arrivals,
      processIntervalMs: 200,
      batchSize: 2
    });
    const freshness = evaluateFreshnessSlo(baseline, 2000);

    expect(freshness.pass).toBe(false);
    expect(freshness.p95LatencyMs).toBeGreaterThan(2000);
  });

  it("freshness.tuned_backpressure_meets_target.red", () => {
    const arrivals = generatePatchArrivals({
      count: 2400,
      baseIntervalMs: 40,
      burstEvery: 120,
      burstSize: 24
    });

    const tuned = runPatchPipelineSimulation({
      arrivals,
      processIntervalMs: 45,
      batchSize: 20
    });
    const freshness = evaluateFreshnessSlo(tuned, 2000);

    expect(freshness.pass).toBe(true);
  });

  it("reliability.long_run_no_unbounded_queue_growth.red", () => {
    const arrivals = generatePatchArrivals({
      count: 20000,
      baseIntervalMs: 25,
      burstEvery: 100,
      burstSize: 30
    });

    const baseline = runPatchPipelineSimulation({
      arrivals,
      processIntervalMs: 110,
      batchSize: 4
    });
    const reliability = evaluateReliabilityBudget(baseline, {
      maxQueueDepth: 512,
      maxDroppedRatio: 0.05
    });

    expect(reliability.pass).toBe(false);
    expect(baseline.maxQueueDepth).toBeGreaterThan(512);
  });

  it("reliability.guardrails_emit_telemetry_and_bound_depth.red", () => {
    const arrivals = generatePatchArrivals({
      count: 20000,
      baseIntervalMs: 25,
      burstEvery: 100,
      burstSize: 30
    });

    const guarded = runPatchPipelineSimulation({
      arrivals,
      processIntervalMs: 45,
      batchSize: 20,
      maxQueueDepth: 512
    });
    const reliability = evaluateReliabilityBudget(guarded, {
      maxQueueDepth: 512,
      maxDroppedRatio: 0.2
    });

    expect(reliability.pass).toBe(true);
    expect(guarded.maxQueueDepth).toBeLessThanOrEqual(512);
    expect(guarded.telemetry.maxQueueDepthObserved).toBeGreaterThan(0);
  });
});
