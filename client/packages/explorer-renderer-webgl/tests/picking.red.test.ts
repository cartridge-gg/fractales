import { describe, expect, it } from "vitest";
import {
  encodePickIdToRgba,
  pickHexCoordinateAt,
  type PickBufferFixture
} from "../src/picking.js";

function putPixel(
  rgba: Uint8Array,
  width: number,
  x: number,
  y: number,
  color: readonly [number, number, number, number]
): void {
  const offset = (y * width + x) * 4;
  rgba[offset] = color[0];
  rgba[offset + 1] = color[1];
  rgba[offset + 2] = color[2];
  rgba[offset + 3] = color[3];
}

describe("picking (RED)", () => {
  it("picking.decode_id_buffer_fixture_to_hex.red", () => {
    const rgba = new Uint8Array(3 * 2 * 4);
    putPixel(rgba, 3, 1, 0, encodePickIdToRgba(42));

    const fixture: PickBufferFixture = {
      width: 3,
      height: 2,
      rgba,
      idToHex: {
        42: "0xabc"
      }
    };

    expect(pickHexCoordinateAt(fixture, 1, 0)).toBe("0xabc");
  });

  it("picking.pointer_and_touch_coords_floor_to_pixel.red", () => {
    const rgba = new Uint8Array(3 * 2 * 4);
    putPixel(rgba, 3, 2, 1, encodePickIdToRgba(7));

    const fixture: PickBufferFixture = {
      width: 3,
      height: 2,
      rgba,
      idToHex: {
        7: "0x7"
      }
    };

    expect(pickHexCoordinateAt(fixture, 2.9, 1.8)).toBe("0x7");
  });

  it("picking.out_of_bounds_or_unknown_id_returns_null.red", () => {
    const rgba = new Uint8Array(2 * 1 * 4);
    putPixel(rgba, 2, 0, 0, encodePickIdToRgba(999));
    putPixel(rgba, 2, 1, 0, encodePickIdToRgba(0));

    const fixture: PickBufferFixture = {
      width: 2,
      height: 1,
      rgba,
      idToHex: {
        42: "0x42"
      }
    };

    expect(pickHexCoordinateAt(fixture, -1, 0)).toBeNull();
    expect(pickHexCoordinateAt(fixture, 2, 0)).toBeNull();
    expect(pickHexCoordinateAt(fixture, 0, 0)).toBeNull();
    expect(pickHexCoordinateAt(fixture, 1, 0)).toBeNull();
  });
});
