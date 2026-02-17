import type { HexCoordinate } from "@gen-dungeon/explorer-types";

export interface PickBufferFixture {
  width: number;
  height: number;
  rgba: Uint8Array;
  idToHex: Record<number, HexCoordinate>;
}

export function encodePickIdToRgba(
  id: number
): readonly [number, number, number, number] {
  const bounded = clampToPickIdRange(id);
  return [
    bounded & 0xff,
    (bounded >> 8) & 0xff,
    (bounded >> 16) & 0xff,
    0xff
  ];
}

export function decodePickIdFromRgba(
  color: readonly [number, number, number, number]
): number {
  return color[0] + (color[1] << 8) + (color[2] << 16);
}

export function pickHexCoordinateAt(
  fixture: PickBufferFixture,
  pointerX: number,
  pointerY: number
): HexCoordinate | null {
  const pixelX = Math.floor(pointerX);
  const pixelY = Math.floor(pointerY);
  if (
    pixelX < 0 ||
    pixelY < 0 ||
    pixelX >= fixture.width ||
    pixelY >= fixture.height
  ) {
    return null;
  }

  const color = readPixelColor(fixture.rgba, fixture.width, pixelX, pixelY);
  const id = decodePickIdFromRgba(color);
  if (id === 0) {
    return null;
  }

  return fixture.idToHex[id] ?? null;
}

function readPixelColor(
  rgba: Uint8Array,
  width: number,
  x: number,
  y: number
): readonly [number, number, number, number] {
  const offset = (y * width + x) * 4;
  return [
    rgba[offset] ?? 0,
    rgba[offset + 1] ?? 0,
    rgba[offset + 2] ?? 0,
    rgba[offset + 3] ?? 0
  ];
}

function clampToPickIdRange(id: number): number {
  const normalized = Number.isFinite(id) ? Math.floor(id) : 0;
  if (normalized < 0) {
    return 0;
  }

  if (normalized > 0xffffff) {
    return 0xffffff;
  }

  return normalized;
}
