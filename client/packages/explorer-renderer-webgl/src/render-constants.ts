export type DrawPass = "grid" | "hex" | "overlay" | "glyph";

export const DRAW_PASS_ORDER: readonly DrawPass[] = [
  "grid",
  "hex",
  "overlay",
  "glyph"
];

export const SHADER_KEYS: Readonly<Record<DrawPass, string>> = {
  grid: "grid-lines-v1",
  hex: "hex-fill-v1",
  overlay: "overlay-symbol-v1",
  glyph: "glyph-atlas-v1"
};

export const CLAIM_OVERLAY_SYMBOLS = {
  active: "C",
  claimable: "!",
  idle: "."
} as const;

export const CLAIM_GLYPHS = {
  active: "CLM",
  claimable: "ALR",
  idle: "DOT"
} as const;

export const BIOME_GLYPHS: Readonly<Record<string, string>> = {
  Plains: "PLN",
  Forest: "FOR",
  Desert: "DES"
};
