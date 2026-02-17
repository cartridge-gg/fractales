import { describe, expect, it } from "vitest";
import {
  buildScriptedCameraPath,
  evaluatePerfBudgets,
  runPerfHarness,
  type PerfSceneFixture
} from "../src/perf-harness.js";

const fixture: PerfSceneFixture = {
  name: "dense_frontier",
  baseVisibleChunks: 120,
  avgHexesPerChunk: 32,
  glyphDensity: 0.3
};

describe("perf harness (RED)", () => {
  it("perf.harness_scripted_camera_path_is_deterministic.red", () => {
    const pathA = buildScriptedCameraPath({
      frames: 180,
      radius: 6,
      zoomMin: 0.8,
      zoomMax: 1.8
    });
    const pathB = buildScriptedCameraPath({
      frames: 180,
      radius: 6,
      zoomMin: 0.8,
      zoomMax: 1.8
    });

    expect(pathA).toEqual(pathB);
  });

  it("perf.harness_flags_threshold_failures_pre_optimization.red", () => {
    const path = buildScriptedCameraPath({
      frames: 240,
      radius: 8,
      zoomMin: 0.75,
      zoomMax: 1.9
    });
    const baseline = runPerfHarness({
      scene: fixture,
      path,
      mode: "baseline"
    });

    const budget = evaluatePerfBudgets(baseline, {
      minFps: 30,
      maxP95FrameTimeMs: 33.34
    });

    expect(budget.pass).toBe(false);
    expect(budget.failures).toContain("fps");
  });

  it("perf.optimized_pipeline_improves_fps_and_frame_time.red", () => {
    const path = buildScriptedCameraPath({
      frames: 240,
      radius: 8,
      zoomMin: 0.75,
      zoomMax: 1.9
    });
    const baseline = runPerfHarness({
      scene: fixture,
      path,
      mode: "baseline"
    });
    const optimized = runPerfHarness({
      scene: fixture,
      path,
      mode: "optimized"
    });

    const budget = evaluatePerfBudgets(optimized, {
      minFps: 30,
      maxP95FrameTimeMs: 33.34
    });

    expect(optimized.avgFps).toBeGreaterThan(baseline.avgFps);
    expect(optimized.p95FrameTimeMs).toBeLessThan(baseline.p95FrameTimeMs);
    expect(budget.pass).toBe(true);
  });
});
