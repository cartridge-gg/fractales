import {
  applyRendererPerfOptimizations,
  BASELINE_PERF_PROFILE,
  OPTIMIZED_PERF_PROFILE
} from "./perf-optimizations.js";

export interface PerfSceneFixture {
  name: string;
  baseVisibleChunks: number;
  avgHexesPerChunk: number;
  glyphDensity: number;
}

export interface ScriptedCameraPathFrame {
  x: number;
  y: number;
  zoom: number;
}

export interface BuildScriptedCameraPathOptions {
  frames: number;
  radius: number;
  zoomMin: number;
  zoomMax: number;
  centerX?: number;
  centerY?: number;
}

export type PerfHarnessMode = "baseline" | "optimized";

export interface RunPerfHarnessInput {
  scene: PerfSceneFixture;
  path: ScriptedCameraPathFrame[];
  mode: PerfHarnessMode;
}

export interface PerfHarnessMetrics {
  mode: PerfHarnessMode;
  frameTimesMs: number[];
  avgFrameTimeMs: number;
  p95FrameTimeMs: number;
  avgFps: number;
  avgVisibleChunks: number;
}

export interface PerfBudget {
  minFps: number;
  maxP95FrameTimeMs: number;
}

export interface PerfBudgetResult {
  pass: boolean;
  failures: Array<"fps" | "p95_frame_time">;
}

export function buildScriptedCameraPath(
  options: BuildScriptedCameraPathOptions
): ScriptedCameraPathFrame[] {
  const centerX = options.centerX ?? 0;
  const centerY = options.centerY ?? 0;
  const zoomSpan = options.zoomMax - options.zoomMin;
  const frames: ScriptedCameraPathFrame[] = [];

  for (let index = 0; index < options.frames; index += 1) {
    const progress = index / Math.max(1, options.frames - 1);
    const angle = progress * Math.PI * 2;
    const orbitWobble = 1 + 0.2 * Math.sin(progress * Math.PI * 4);
    frames.push({
      x: centerX + Math.cos(angle) * options.radius * orbitWobble,
      y: centerY + Math.sin(angle) * options.radius * orbitWobble,
      zoom: options.zoomMin + zoomSpan * (0.5 + 0.5 * Math.sin(progress * Math.PI * 2))
    });
  }

  return frames;
}

export function runPerfHarness(input: RunPerfHarnessInput): PerfHarnessMetrics {
  const coefficients = input.mode === "optimized"
    ? { baseMs: 6.5, chunkMs: 0.07, drawCommandMs: 0.003, glyphMs: 0.0015 }
    : { baseMs: 9, chunkMs: 0.11, drawCommandMs: 0.006, glyphMs: 0.003 };
  const profile = input.mode === "optimized"
    ? OPTIMIZED_PERF_PROFILE
    : BASELINE_PERF_PROFILE;

  const frameTimesMs: number[] = [];
  const visibleChunksSeries: number[] = [];

  for (let index = 0; index < input.path.length; index += 1) {
    const frame = input.path[index];
    if (!frame) {
      continue;
    }

    const movementFactor = Math.hypot(frame.x, frame.y) * 0.015;
    const zoomFactor = (frame.zoom - 1) * 0.09;
    const oscillationFactor = 0.08 * Math.sin(index * 0.19);
    const visibleChunks = Math.max(
      1,
      Math.round(
        input.scene.baseVisibleChunks *
          (1 + movementFactor + zoomFactor + oscillationFactor)
      )
    );
    visibleChunksSeries.push(visibleChunks);

    const drawCommands = visibleChunks * input.scene.avgHexesPerChunk * 0.8;
    const glyphCount = visibleChunks * input.scene.avgHexesPerChunk * input.scene.glyphDensity;
    const workload = applyRendererPerfOptimizations(
      {
        visibleChunks,
        drawCommands,
        glyphCount
      },
      profile
    );
    const frameTime =
      coefficients.baseMs +
      workload.visibleChunks * coefficients.chunkMs +
      workload.drawCommands * coefficients.drawCommandMs +
      workload.glyphCount * coefficients.glyphMs;
    frameTimesMs.push(frameTime);
  }

  const avgFrameTimeMs = average(frameTimesMs);
  const p95FrameTimeMs = percentile(frameTimesMs, 0.95);
  const avgFps = avgFrameTimeMs > 0 ? 1000 / avgFrameTimeMs : 0;

  return {
    mode: input.mode,
    frameTimesMs,
    avgFrameTimeMs,
    p95FrameTimeMs,
    avgFps,
    avgVisibleChunks: average(visibleChunksSeries)
  };
}

export function evaluatePerfBudgets(
  metrics: PerfHarnessMetrics,
  budget: PerfBudget
): PerfBudgetResult {
  const failures: Array<"fps" | "p95_frame_time"> = [];
  if (metrics.avgFps < budget.minFps) {
    failures.push("fps");
  }
  if (metrics.p95FrameTimeMs > budget.maxP95FrameTimeMs) {
    failures.push("p95_frame_time");
  }
  return {
    pass: failures.length === 0,
    failures
  };
}

function percentile(values: number[], p: number): number {
  if (values.length === 0) {
    return 0;
  }

  const sorted = [...values].sort((a, b) => a - b);
  const index = Math.min(
    sorted.length - 1,
    Math.max(0, Math.ceil(sorted.length * p) - 1)
  );
  const value = sorted[index];
  return value ?? 0;
}

function average(values: number[]): number {
  if (values.length === 0) {
    return 0;
  }

  return values.reduce((sum, value) => sum + value, 0) / values.length;
}
