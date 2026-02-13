import { describe, expect, it } from "vitest";
import type { ChunkKey } from "@gen-dungeon/explorer-types";
import { validateChunkQuery, validateSearchQuery } from "../src/proxy-contracts";

describe("proxy contracts (RED->GREEN)", () => {
  it("rejects oversized chunk key sets", () => {
    const keys = Array.from({ length: 130 }, (_, i) => `0:${i}` as ChunkKey);
    const result = validateChunkQuery({ keys });

    expect(result.ok).toBe(false);
    expect(result.error).toContain("max");
  });

  it("dedupes and accepts chunk key sets within bounds", () => {
    const result = validateChunkQuery({ keys: ["0:0", "0:0", "1:0"] });

    expect(result.ok).toBe(true);
    expect(result.value?.keys).toEqual(["0:0", "1:0"]);
  });

  it("rejects search queries with multiple modes", () => {
    const result = validateSearchQuery({ coord: "0x1", owner: "0x2" });

    expect(result.ok).toBe(false);
  });

  it("normalizes search query with default limit", () => {
    const result = validateSearchQuery({ owner: "0x2" });

    expect(result.ok).toBe(true);
    expect(result.value?.limit).toBe(20);
    expect(result.value?.mode).toBe("owner");
  });
});
