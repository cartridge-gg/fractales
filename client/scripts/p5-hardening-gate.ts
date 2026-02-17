import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import {
  buildScriptedCameraPath,
  evaluatePerfBudgets,
  runPerfHarness,
  type PerfSceneFixture
} from "../packages/explorer-renderer-webgl/src/perf-harness.ts";
import {
  evaluateFreshnessSlo,
  evaluateReliabilityBudget,
  generatePatchArrivals,
  runPatchPipelineSimulation
} from "../packages/explorer-data/src/perf-reliability.ts";

const DEFAULT_REPORT_PATH = "artifacts/p5-hardening-gate-report.json";

const THRESHOLDS = {
  freshnessP95LatencyMs: 2000,
  minFps: 30,
  maxP95FrameTimeMs: 33.34,
  maxQueueDepth: 512,
  maxDroppedRatio: 0.2
} as const;

const RENDERER_FIXTURE: PerfSceneFixture = {
  name: "dense_frontier",
  baseVisibleChunks: 120,
  avgHexesPerChunk: 32,
  glyphDensity: 0.3
};

const REPORT_PATH = parseReportPath(process.argv.slice(2));

const rendererPath = buildScriptedCameraPath({
  frames: 240,
  radius: 8,
  zoomMin: 0.75,
  zoomMax: 1.9
});
const rendererMetrics = runPerfHarness({
  scene: RENDERER_FIXTURE,
  path: rendererPath,
  mode: "optimized"
});
const rendererBudget = evaluatePerfBudgets(rendererMetrics, {
  minFps: THRESHOLDS.minFps,
  maxP95FrameTimeMs: THRESHOLDS.maxP95FrameTimeMs
});

const arrivals = generatePatchArrivals({
  count: 20000,
  baseIntervalMs: 25,
  burstEvery: 100,
  burstSize: 30
});
const pipelineMetrics = runPatchPipelineSimulation({
  arrivals,
  processIntervalMs: 45,
  batchSize: 20,
  maxQueueDepth: THRESHOLDS.maxQueueDepth
});
const freshness = evaluateFreshnessSlo(
  pipelineMetrics,
  THRESHOLDS.freshnessP95LatencyMs
);
const reliability = evaluateReliabilityBudget(pipelineMetrics, {
  maxQueueDepth: THRESHOLDS.maxQueueDepth,
  maxDroppedRatio: THRESHOLDS.maxDroppedRatio
});

const failures: string[] = [];
if (!rendererBudget.pass) {
  failures.push(...rendererBudget.failures.map((failure) => `renderer:${failure}`));
}
if (!freshness.pass) {
  failures.push("freshness:p95_latency");
}
if (!reliability.pass) {
  failures.push("reliability:queue_budget");
}

const report = {
  generatedAt: new Date().toISOString(),
  pass: failures.length === 0,
  failures,
  thresholds: THRESHOLDS,
  renderer: {
    metrics: {
      avgFps: round(rendererMetrics.avgFps),
      avgFrameTimeMs: round(rendererMetrics.avgFrameTimeMs),
      p95FrameTimeMs: round(rendererMetrics.p95FrameTimeMs),
      avgVisibleChunks: round(rendererMetrics.avgVisibleChunks)
    },
    budget: rendererBudget
  },
  freshness,
  reliability,
  pipelineTelemetry: pipelineMetrics.telemetry
};

writeReport(REPORT_PATH, report);
printSummary(REPORT_PATH, report);

if (!report.pass) {
  process.exitCode = 1;
}

function parseReportPath(args: string[]): string {
  for (let index = 0; index < args.length; index += 1) {
    const current = args[index];
    if (!current) {
      continue;
    }
    if (current.startsWith("--report=")) {
      const value = current.slice("--report=".length).trim();
      if (value.length > 0) {
        return value;
      }
    }
    if (current === "--report") {
      const next = args[index + 1];
      if (next && !next.startsWith("--")) {
        return next;
      }
    }
  }
  return DEFAULT_REPORT_PATH;
}

function writeReport(path: string, value: unknown): void {
  const outputPath = resolve(path);
  mkdirSync(dirname(outputPath), { recursive: true });
  writeFileSync(outputPath, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

function printSummary(path: string, value: typeof report): void {
  console.log(`hardening gate report: ${resolve(path)}`);
  console.log(`pass: ${value.pass}`);
  console.log(
    `renderer avg_fps=${value.renderer.metrics.avgFps} p95_frame_ms=${value.renderer.metrics.p95FrameTimeMs}`
  );
  console.log(
    `freshness p95_latency_ms=${value.freshness.p95LatencyMs} pass=${value.freshness.pass}`
  );
  console.log(
    `reliability max_queue_depth=${value.reliability.maxQueueDepth} dropped_ratio=${round(value.reliability.droppedRatio)} pass=${value.reliability.pass}`
  );
  if (!value.pass) {
    console.error(`failures: ${value.failures.join(", ")}`);
  }
}

function round(value: number): number {
  return Number(value.toFixed(3));
}
