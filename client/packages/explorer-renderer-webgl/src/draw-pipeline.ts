import type { ChunkSnapshot } from "@gen-dungeon/explorer-types";
import { batchDrawCommands, type DrawCommand } from "./draw-batching.js";
import {
  BIOME_GLYPHS,
  CLAIM_GLYPHS,
  CLAIM_OVERLAY_SYMBOLS
} from "./render-constants.js";

export type OverlayMode = "biome" | "claims";

export function renderSceneSnapshot(
  chunks: ChunkSnapshot[],
  overlayMode: OverlayMode
): string {
  const commands = buildDrawCommands(chunks, overlayMode);
  return commands.map((command) => `${command.pass}|${command.key}|${command.symbol}`).join("\n");
}

export function renderGlyphAtlasSnapshot(glyphs: string[]): string {
  const ordered = [...glyphs].sort();
  return ordered
    .map((glyph) => `${glyph}|${glyphToHexCodes(glyph)}`)
    .join("\n");
}

function buildDrawCommands(
  chunks: ChunkSnapshot[],
  overlayMode: OverlayMode
): DrawCommand[] {
  const orderedChunks = [...chunks].sort((a, b) => compareChunkKeys(a.chunk.key, b.chunk.key));
  const rawCommands: DrawCommand[] = [];

  for (const chunk of orderedChunks) {
    rawCommands.push({
      pass: "grid",
      key: chunk.chunk.key,
      symbol: "#"
    });

    const orderedHexes = [...chunk.hexes].sort((a, b) =>
      a.hexCoordinate.localeCompare(b.hexCoordinate)
    );
    for (const hex of orderedHexes) {
      rawCommands.push({
        pass: "hex",
        key: hex.hexCoordinate,
        symbol: "H"
      });
    }

    for (const hex of orderedHexes) {
      const overlaySymbol = overlayForHex(hex, overlayMode);
      rawCommands.push({
        pass: "overlay",
        key: hex.hexCoordinate,
        symbol: overlaySymbol
      });
    }

    for (const hex of orderedHexes) {
      const glyph = glyphForHex(hex, overlayMode);
      rawCommands.push({
        pass: "glyph",
        key: hex.hexCoordinate,
        symbol: glyph
      });
    }
  }

  return batchDrawCommands(rawCommands).flatMap((batch) => batch.commands);
}

function overlayForHex(
  hex: ChunkSnapshot["hexes"][number],
  mode: OverlayMode
): string {
  if (mode === "biome") {
    return biomeOverlaySymbol(hex.biome);
  }

  if (hex.activeClaimCount > 0) {
    return CLAIM_OVERLAY_SYMBOLS.active;
  }

  if (hex.isClaimable) {
    return CLAIM_OVERLAY_SYMBOLS.claimable;
  }

  return CLAIM_OVERLAY_SYMBOLS.idle;
}

function glyphForHex(
  hex: ChunkSnapshot["hexes"][number],
  mode: OverlayMode
): string {
  if (mode === "biome") {
    return biomeGlyph(hex.biome);
  }

  if (hex.activeClaimCount > 0) {
    return CLAIM_GLYPHS.active;
  }

  if (hex.isClaimable) {
    return CLAIM_GLYPHS.claimable;
  }

  return CLAIM_GLYPHS.idle;
}

function biomeOverlaySymbol(biome: string): string {
  return biomeGlyph(biome).charAt(0);
}

function biomeGlyph(biome: string): string {
  const canonical = BIOME_GLYPHS[biome];
  if (canonical) {
    return canonical;
  }
  return biome.replace(/[^a-z0-9]/gi, "").slice(0, 3).toUpperCase().padEnd(3, "_");
}

function glyphToHexCodes(glyph: string): string {
  return Array.from(glyph)
    .map((char) => char.charCodeAt(0).toString(16).toUpperCase().padStart(2, "0"))
    .join("-");
}

function compareChunkKeys(a: string, b: string): number {
  const [aq, ar] = parseChunkKey(a);
  const [bq, br] = parseChunkKey(b);

  if (aq !== bq) {
    return aq - bq;
  }

  return ar - br;
}

function parseChunkKey(key: string): [number, number] {
  const [qRaw, rRaw] = key.split(":").map((value) => Number.parseInt(value, 10));
  return [qRaw ?? 0, rRaw ?? 0];
}
