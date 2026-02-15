import type { ChunkKey, SearchQuery } from "@gen-dungeon/explorer-types";

const DEFAULT_SEARCH_LIMIT = 20;
const MAX_SEARCH_LIMIT = 100;
const MAX_CHUNK_KEYS = 128;

export interface ValidationSuccess<T> {
  ok: true;
  value: T;
}

export interface ValidationError {
  ok: false;
  error: string;
}

export type ValidationResult<T> = ValidationSuccess<T> | ValidationError;

export interface ChunkQueryInput {
  keys: ChunkKey[];
}

export interface NormalizedChunkQuery {
  keys: ChunkKey[];
}

export type SearchMode = "coord" | "owner" | "adventurer";

export interface NormalizedSearchQuery {
  mode: SearchMode;
  value: string;
  limit: number;
}

export function validateChunkQuery(
  input: ChunkQueryInput,
  maxChunkKeys: number = MAX_CHUNK_KEYS
): ValidationResult<NormalizedChunkQuery> {
  if (input.keys.length === 0) {
    return { ok: false, error: "chunk key set must not be empty" };
  }

  if (input.keys.length > maxChunkKeys) {
    return {
      ok: false,
      error: `chunk key set exceeds max of ${maxChunkKeys}`
    };
  }

  return {
    ok: true,
    value: {
      keys: Array.from(new Set(input.keys))
    }
  };
}

export function validateSearchQuery(
  query: SearchQuery
): ValidationResult<NormalizedSearchQuery> {
  const modes = [
    query.coord ? ["coord", query.coord] : null,
    query.owner ? ["owner", query.owner] : null,
    query.adventurer ? ["adventurer", query.adventurer] : null
  ].filter(Boolean) as Array<[SearchMode, string]>;

  if (modes.length !== 1) {
    return {
      ok: false,
      error: "search query must provide exactly one mode: coord, owner, or adventurer"
    };
  }

  const selectedMode = modes[0];
  if (!selectedMode) {
    return {
      ok: false,
      error: "search query must provide exactly one mode: coord, owner, or adventurer"
    };
  }
  const [mode, value] = selectedMode;
  const limit = query.limit ?? DEFAULT_SEARCH_LIMIT;

  if (!Number.isInteger(limit) || limit < 1 || limit > MAX_SEARCH_LIMIT) {
    return {
      ok: false,
      error: `search limit must be an integer between 1 and ${MAX_SEARCH_LIMIT}`
    };
  }

  return {
    ok: true,
    value: {
      mode,
      value,
      limit
    }
  };
}
