import { describe, expect, it } from "vitest";
import {
  decodeHexCoordinateCube,
  encodeHexCoordinateCube,
  expandHexWindowCoordinates,
  isPointInHexPolygon,
  layoutHexCoordinates
} from "../src/hex-layout.js";

const HEX_LEFT = "0x3ffffe0000100001"; // (-1, 0, 1)
const HEX_TOP_LEFT = "0x3ffffe0000300000"; // (-1, 1, 0)
const HEX_TOP_RIGHT = "0x40000200002fffff"; // (0, 1, -1)
const HEX_RIGHT = "0x40000600000fffff"; // (1, 0, -1)
const HEX_BOTTOM_RIGHT = "0x400005fffff00000"; // (1, -1, 0)

describe("hex layout geometry (RED)", () => {
  it("decodes live coordinates and rejects invalid cube packing.red", () => {
    expect(decodeHexCoordinateCube(HEX_LEFT)).toEqual({ x: -1, y: 0, z: 1 });
    expect(decodeHexCoordinateCube(HEX_TOP_RIGHT)).toEqual({ x: 0, y: 1, z: -1 });

    // Invalid cube sum from an intentionally malformed packed coordinate.
    expect(decodeHexCoordinateCube("0x3ffffd0000200003")).toBeNull();
  });

  it("lays out map as hex polygons instead of circles.red", () => {
    const layout = layoutHexCoordinates(
      [HEX_LEFT, HEX_TOP_LEFT, HEX_TOP_RIGHT, HEX_RIGHT, HEX_BOTTOM_RIGHT],
      1200,
      760
    );

    expect(layout).toHaveLength(5);

    const byCoord = new Map(layout.map((entry) => [entry.hexCoordinate, entry]));
    for (const coordinate of [HEX_LEFT, HEX_TOP_LEFT, HEX_TOP_RIGHT, HEX_RIGHT, HEX_BOTTOM_RIGHT]) {
      const entry = byCoord.get(coordinate);
      expect(entry).toBeDefined();
      expect(entry?.vertices).toHaveLength(6);
    }

    const topRight = byCoord.get(HEX_TOP_RIGHT);
    const left = byCoord.get(HEX_LEFT);
    if (!topRight || !left) {
      throw new Error("expected required hex entries");
    }

    // Reflect cube map orientation: z=-1 appears visually above z=+1.
    expect(topRight.y).toBeLessThan(left.y);

    // Hit-testing must follow polygon shape.
    expect(isPointInHexPolygon(left.x, left.y, left.vertices)).toBe(true);
    expect(
      isPointInHexPolygon(
        left.x + left.radius * 1.5,
        left.y + left.radius * 1.5,
        left.vertices
      )
    ).toBe(false);
  });

  it("expands discovered map into explored plus unexplored hex window.red", () => {
    const discovered = [HEX_LEFT, HEX_TOP_LEFT, HEX_TOP_RIGHT, HEX_RIGHT, HEX_BOTTOM_RIGHT];
    const expanded = expandHexWindowCoordinates(discovered, 2);

    expect(expanded.length).toBeGreaterThan(discovered.length);
    for (const coordinate of discovered) {
      expect(expanded).toContain(coordinate);
    }

    const center = encodeHexCoordinateCube({ x: 0, y: 0, z: 0 });
    expect(center).toBeDefined();
    if (!center) {
      throw new Error("center coordinate should encode");
    }
    expect(expanded).toContain(center);
    expect(decodeHexCoordinateCube(center)).toEqual({ x: 0, y: 0, z: 0 });
  });
});
