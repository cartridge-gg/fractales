import type { ChunkKey, SearchQuery } from "@gen-dungeon/explorer-types";

export function parseChunkKeysFromUrl(url: URL): ChunkKey[] {
  const rawKeys = url.searchParams.get("keys");
  if (!rawKeys) {
    throw new Error("keys query parameter is required");
  }

  const keys = rawKeys
    .split(",")
    .map((key) => key.trim())
    .filter((key) => key.length > 0) as ChunkKey[];

  if (keys.length === 0) {
    throw new Error("keys query parameter must include at least one chunk key");
  }

  return keys;
}

export function parseHexCoordinateFromPath(pathname: string): string {
  const prefix = "/v1/hex/";
  if (!pathname.startsWith(prefix)) {
    throw new Error("invalid hex endpoint path");
  }

  const encoded = pathname.slice(prefix.length).trim();
  if (!encoded) {
    throw new Error("hex coordinate path segment is required");
  }

  return decodeURIComponent(encoded);
}

export function parseSearchQueryFromUrl(url: URL): SearchQuery {
  const coord = url.searchParams.get("coord");
  const owner = url.searchParams.get("owner");
  const adventurer = url.searchParams.get("adventurer");
  const limitRaw = url.searchParams.get("limit");
  let limit: number | undefined;
  if (limitRaw !== null) {
    const parsedLimit = Number.parseInt(limitRaw, 10);
    if (!Number.isInteger(parsedLimit) || parsedLimit <= 0) {
      throw new Error("search limit must be a positive integer");
    }
    limit = parsedLimit;
  }

  const modeCount =
    Number(coord !== null) +
    Number(owner !== null) +
    Number(adventurer !== null);
  if (modeCount !== 1) {
    throw new Error("search query must provide exactly one mode: coord, owner, or adventurer");
  }

  const query: SearchQuery = {};
  if (coord !== null) {
    query.coord = coord;
  }
  if (owner !== null) {
    query.owner = owner;
  }
  if (adventurer !== null) {
    query.adventurer = adventurer;
  }
  if (limit !== undefined) {
    query.limit = limit;
  }

  return query;
}
