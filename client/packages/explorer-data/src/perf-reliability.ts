export interface PatchArrival {
  includedAtMs: number;
}

export interface GeneratePatchArrivalsOptions {
  count: number;
  baseIntervalMs: number;
  burstEvery?: number;
  burstSize?: number;
}

export interface RunPatchPipelineSimulationOptions {
  arrivals: PatchArrival[];
  processIntervalMs: number;
  batchSize: number;
  maxQueueDepth?: number;
}

export interface PipelineTelemetry {
  maxQueueDepthObserved: number;
  droppedForQueueCap: number;
  processedCount: number;
}

export interface PatchPipelineSimulationMetrics {
  latenciesMs: number[];
  p95LatencyMs: number;
  averageLatencyMs: number;
  maxQueueDepth: number;
  droppedCount: number;
  processedCount: number;
  telemetry: PipelineTelemetry;
}

export interface FreshnessSloResult {
  pass: boolean;
  p95LatencyMs: number;
}

export interface ReliabilityBudget {
  maxQueueDepth: number;
  maxDroppedRatio: number;
}

export interface ReliabilityBudgetResult {
  pass: boolean;
  maxQueueDepth: number;
  droppedRatio: number;
}

export function generatePatchArrivals(
  options: GeneratePatchArrivalsOptions
): PatchArrival[] {
  const arrivals: PatchArrival[] = [];
  let currentMs = 0;

  while (arrivals.length < options.count) {
    currentMs += options.baseIntervalMs;
    arrivals.push({ includedAtMs: currentMs });

    const burstEvery = options.burstEvery ?? 0;
    if (burstEvery > 0 && arrivals.length % burstEvery === 0) {
      const burstSize = options.burstSize ?? 0;
      for (
        let burstIndex = 0;
        burstIndex < burstSize && arrivals.length < options.count;
        burstIndex += 1
      ) {
        arrivals.push({ includedAtMs: currentMs + burstIndex });
      }
    }
  }

  return arrivals;
}

export function runPatchPipelineSimulation(
  options: RunPatchPipelineSimulationOptions
): PatchPipelineSimulationMetrics {
  const arrivals = [...options.arrivals].sort(
    (a, b) => a.includedAtMs - b.includedAtMs
  );

  if (arrivals.length === 0) {
    return {
      latenciesMs: [],
      p95LatencyMs: 0,
      averageLatencyMs: 0,
      maxQueueDepth: 0,
      droppedCount: 0,
      processedCount: 0,
      telemetry: {
        maxQueueDepthObserved: 0,
        droppedForQueueCap: 0,
        processedCount: 0
      }
    };
  }

  const queue: PatchArrival[] = [];
  const latenciesMs: number[] = [];
  let arrivalCursor = 0;
  let droppedCount = 0;
  let maxQueueDepth = 0;
  let processedCount = 0;

  let nextProcessAt = arrivals[0]?.includedAtMs ?? 0;
  while (arrivalCursor < arrivals.length || queue.length > 0) {
    const nextArrivalAt = arrivals[arrivalCursor]?.includedAtMs ?? Number.POSITIVE_INFINITY;
    if (nextArrivalAt <= nextProcessAt) {
      const arrival = arrivals[arrivalCursor];
      if (arrival) {
        queue.push(arrival);
      }
      arrivalCursor += 1;

      if (options.maxQueueDepth !== undefined && queue.length > options.maxQueueDepth) {
        queue.shift();
        droppedCount += 1;
      }

      if (queue.length > maxQueueDepth) {
        maxQueueDepth = queue.length;
      }
      continue;
    }

    for (let batchCursor = 0; batchCursor < options.batchSize; batchCursor += 1) {
      const item = queue.shift();
      if (!item) {
        break;
      }
      latenciesMs.push(nextProcessAt - item.includedAtMs);
      processedCount += 1;
    }

    if (queue.length > maxQueueDepth) {
      maxQueueDepth = queue.length;
    }
    nextProcessAt += options.processIntervalMs;
  }

  return {
    latenciesMs,
    p95LatencyMs: percentile(latenciesMs, 0.95),
    averageLatencyMs: average(latenciesMs),
    maxQueueDepth,
    droppedCount,
    processedCount,
    telemetry: {
      maxQueueDepthObserved: maxQueueDepth,
      droppedForQueueCap: droppedCount,
      processedCount
    }
  };
}

export function evaluateFreshnessSlo(
  metrics: PatchPipelineSimulationMetrics,
  maxP95LatencyMs: number
): FreshnessSloResult {
  return {
    pass: metrics.p95LatencyMs <= maxP95LatencyMs,
    p95LatencyMs: metrics.p95LatencyMs
  };
}

export function evaluateReliabilityBudget(
  metrics: PatchPipelineSimulationMetrics,
  budget: ReliabilityBudget
): ReliabilityBudgetResult {
  const total = metrics.processedCount + metrics.droppedCount;
  const droppedRatio = total === 0 ? 0 : metrics.droppedCount / total;
  return {
    pass:
      metrics.maxQueueDepth <= budget.maxQueueDepth &&
      droppedRatio <= budget.maxDroppedRatio,
    maxQueueDepth: metrics.maxQueueDepth,
    droppedRatio
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
