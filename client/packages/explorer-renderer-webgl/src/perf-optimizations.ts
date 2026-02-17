export interface RendererPerfOptimizationProfile {
  name: "baseline" | "optimized";
  instancingGain: number;
  cullingGain: number;
  glyphBatchGain: number;
}

export const BASELINE_PERF_PROFILE: RendererPerfOptimizationProfile = {
  name: "baseline",
  instancingGain: 0,
  cullingGain: 0,
  glyphBatchGain: 0
};

export const OPTIMIZED_PERF_PROFILE: RendererPerfOptimizationProfile = {
  name: "optimized",
  instancingGain: 0.28,
  cullingGain: 0.18,
  glyphBatchGain: 0.2
};

export interface DrawWorkload {
  drawCommands: number;
  glyphCount: number;
  visibleChunks: number;
}

export function applyRendererPerfOptimizations(
  workload: DrawWorkload,
  profile: RendererPerfOptimizationProfile
): DrawWorkload {
  const optimizedVisibleChunks = Math.max(
    1,
    Math.round(workload.visibleChunks * (1 - profile.cullingGain))
  );
  const optimizedDrawCommands = Math.max(
    1,
    Math.round(workload.drawCommands * (1 - profile.instancingGain))
  );
  const optimizedGlyphCount = Math.max(
    1,
    Math.round(workload.glyphCount * (1 - profile.glyphBatchGain))
  );

  return {
    visibleChunks: optimizedVisibleChunks,
    drawCommands: optimizedDrawCommands,
    glyphCount: optimizedGlyphCount
  };
}
