import type { HexCoordinate } from "@gen-dungeon/explorer-types";

export interface CubeCoordinate {
  x: number;
  y: number;
  z: number;
}

export interface HexVertex {
  x: number;
  y: number;
}

export interface HexCoordinateLayout {
  hexCoordinate: HexCoordinate;
  cube: CubeCoordinate;
  x: number;
  y: number;
  radius: number;
  vertices: HexVertex[];
}

export interface HexLayoutOptions {
  padding?: number;
  minRadius?: number;
  maxRadius?: number;
}

const AXIS_OFFSET = 1_048_576n;
const AXIS_MASK = 2_097_151n;
const MAX_PACKED = 9_223_372_036_854_775_807n;
const PACK_X_MULT = 4_398_046_511_104n;
const PACK_Y_MULT = 2_097_152n;
const PACK_RANGE = 2_097_152n;
const SQRT3 = Math.sqrt(3);

export function decodeHexCoordinateCube(
  coordinate: HexCoordinate
): CubeCoordinate | null {
  let packed: bigint;
  try {
    packed = BigInt(coordinate);
  } catch {
    return null;
  }

  if (packed < 0n || packed > MAX_PACKED) {
    return null;
  }

  const xShifted = packed / PACK_X_MULT;
  const yShifted = (packed / PACK_Y_MULT) % PACK_RANGE;
  const zShifted = packed % PACK_RANGE;

  if (xShifted > AXIS_MASK || yShifted > AXIS_MASK || zShifted > AXIS_MASK) {
    return null;
  }

  const x = Number(xShifted - AXIS_OFFSET);
  const y = Number(yShifted - AXIS_OFFSET);
  const z = Number(zShifted - AXIS_OFFSET);

  if (!Number.isSafeInteger(x) || !Number.isSafeInteger(y) || !Number.isSafeInteger(z)) {
    return null;
  }

  if (x + y + z !== 0) {
    return null;
  }

  return { x, y, z };
}

export function encodeHexCoordinateCube(cube: CubeCoordinate): HexCoordinate | null {
  if (
    !Number.isSafeInteger(cube.x) ||
    !Number.isSafeInteger(cube.y) ||
    !Number.isSafeInteger(cube.z)
  ) {
    return null;
  }

  if (cube.x + cube.y + cube.z !== 0) {
    return null;
  }

  const xShifted = BigInt(cube.x) + AXIS_OFFSET;
  const yShifted = BigInt(cube.y) + AXIS_OFFSET;
  const zShifted = BigInt(cube.z) + AXIS_OFFSET;

  if (
    xShifted < 0n ||
    yShifted < 0n ||
    zShifted < 0n ||
    xShifted > AXIS_MASK ||
    yShifted > AXIS_MASK ||
    zShifted > AXIS_MASK
  ) {
    return null;
  }

  const packed = xShifted * PACK_X_MULT + yShifted * PACK_Y_MULT + zShifted;
  if (packed < 0n || packed > MAX_PACKED) {
    return null;
  }

  return `0x${packed.toString(16)}`;
}

export function buildHexPolygonVertices(
  centerX: number,
  centerY: number,
  radius: number
): HexVertex[] {
  const vertices: HexVertex[] = [];
  for (let index = 0; index < 6; index += 1) {
    const angleRad = ((60 * index - 30) * Math.PI) / 180;
    vertices.push({
      x: centerX + Math.cos(angleRad) * radius,
      y: centerY + Math.sin(angleRad) * radius
    });
  }
  return vertices;
}

export function isPointInHexPolygon(
  x: number,
  y: number,
  vertices: readonly HexVertex[]
): boolean {
  if (vertices.length < 3) {
    return false;
  }

  let inside = false;
  for (let i = 0, j = vertices.length - 1; i < vertices.length; j = i, i += 1) {
    const vi = vertices[i];
    const vj = vertices[j];
    if (!vi || !vj) {
      continue;
    }

    const intersects =
      (vi.y > y) !== (vj.y > y) &&
      x < ((vj.x - vi.x) * (y - vi.y)) / ((vj.y - vi.y) || Number.EPSILON) + vi.x;

    if (intersects) {
      inside = !inside;
    }
  }

  return inside;
}

export function layoutHexCoordinates(
  hexCoordinates: readonly HexCoordinate[],
  width: number,
  height: number,
  options: HexLayoutOptions = {}
): HexCoordinateLayout[] {
  if (hexCoordinates.length === 0) {
    return [];
  }

  const deduped = dedupeCoordinates(hexCoordinates);
  const decoded = deduped
    .map((hexCoordinate) => {
      const cube = decodeHexCoordinateCube(hexCoordinate);
      if (!cube) {
        return null;
      }
      const unitX = SQRT3 * (cube.x + cube.z / 2);
      const unitY = 1.5 * cube.z;
      return {
        hexCoordinate,
        cube,
        unitX,
        unitY
      };
    })
    .filter((entry): entry is NonNullable<typeof entry> => entry !== null);

  if (decoded.length === 0) {
    return [];
  }

  const minUnitX = Math.min(...decoded.map((entry) => entry.unitX));
  const maxUnitX = Math.max(...decoded.map((entry) => entry.unitX));
  const minUnitY = Math.min(...decoded.map((entry) => entry.unitY));
  const maxUnitY = Math.max(...decoded.map((entry) => entry.unitY));
  const spanUnitX = maxUnitX - minUnitX;
  const spanUnitY = maxUnitY - minUnitY;

  const padding = options.padding ?? 42;
  const minRadius = options.minRadius ?? 20;
  const maxRadius = options.maxRadius ?? 48;

  const safeWidth = Math.max(1, width - padding * 2);
  const safeHeight = Math.max(1, height - padding * 2);

  const radiusFromWidth = safeWidth / Math.max(SQRT3, spanUnitX + SQRT3);
  const radiusFromHeight = safeHeight / Math.max(2, spanUnitY + 2);
  const radius = clamp(Math.min(radiusFromWidth, radiusFromHeight), minRadius, maxRadius);

  const centerUnitX = (minUnitX + maxUnitX) / 2;
  const centerUnitY = (minUnitY + maxUnitY) / 2;
  const centerPixelX = width / 2;
  const centerPixelY = height / 2;

  return decoded
    .map((entry) => {
      const x = centerPixelX + (entry.unitX - centerUnitX) * radius;
      const y = centerPixelY + (entry.unitY - centerUnitY) * radius;
      return {
        hexCoordinate: entry.hexCoordinate,
        cube: entry.cube,
        x,
        y,
        radius,
        vertices: buildHexPolygonVertices(x, y, radius)
      };
    })
    .sort((left, right) =>
      normalizeHexCoordinate(left.hexCoordinate).localeCompare(
        normalizeHexCoordinate(right.hexCoordinate)
      )
    );
}

export function expandHexWindowCoordinates(
  coordinates: readonly HexCoordinate[],
  padding: number = 2
): HexCoordinate[] {
  const deduped = dedupeCoordinates(coordinates);
  const decoded = deduped
    .map((hexCoordinate) => decodeHexCoordinateCube(hexCoordinate))
    .filter((entry): entry is CubeCoordinate => entry !== null);

  if (decoded.length === 0) {
    return deduped;
  }

  const minX = Math.min(...decoded.map((entry) => entry.x));
  const maxX = Math.max(...decoded.map((entry) => entry.x));
  const minY = Math.min(...decoded.map((entry) => entry.y));
  const maxY = Math.max(...decoded.map((entry) => entry.y));
  const minZ = Math.min(...decoded.map((entry) => entry.z));
  const maxZ = Math.max(...decoded.map((entry) => entry.z));
  const safePadding = Math.max(0, Math.floor(padding));

  const byNormalized = new Map<string, HexCoordinate>();
  for (const coordinate of deduped) {
    byNormalized.set(normalizeHexCoordinate(coordinate), coordinate);
  }

  for (let x = minX - safePadding; x <= maxX + safePadding; x += 1) {
    for (let z = minZ - safePadding; z <= maxZ + safePadding; z += 1) {
      const y = -x - z;
      if (y < minY - safePadding || y > maxY + safePadding) {
        continue;
      }

      const encoded = encodeHexCoordinateCube({ x, y, z });
      if (!encoded) {
        continue;
      }

      const normalized = normalizeHexCoordinate(encoded);
      if (!byNormalized.has(normalized)) {
        byNormalized.set(normalized, encoded);
      }
    }
  }

  return Array.from(byNormalized.values()).sort((left, right) =>
    normalizeHexCoordinate(left).localeCompare(normalizeHexCoordinate(right))
  );
}

function dedupeCoordinates(
  coordinates: readonly HexCoordinate[]
): HexCoordinate[] {
  const byNormalized = new Map<string, HexCoordinate>();
  for (const coordinate of coordinates) {
    const normalized = normalizeHexCoordinate(coordinate);
    if (!byNormalized.has(normalized)) {
      byNormalized.set(normalized, coordinate);
    }
  }
  return Array.from(byNormalized.values());
}

function normalizeHexCoordinate(
  coordinate: HexCoordinate
): string {
  return String(coordinate).toLowerCase();
}

function clamp(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) {
    return min;
  }

  if (value < min) {
    return min;
  }

  if (value > max) {
    return max;
  }

  return value;
}
