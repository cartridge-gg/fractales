import type { ExplorerProxyApi } from "./contracts.js";
import {
  parseChunkKeysFromUrl,
  parseHexCoordinateFromPath,
  parseSearchQueryFromUrl
} from "./http-mapping.js";

const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8"
} as const;

export async function handleExplorerProxyHttpRequest(
  api: ExplorerProxyApi,
  request: Request
): Promise<Response> {
  if (request.method !== "GET") {
    return jsonResponse(405, { error: "method not allowed" });
  }

  const url = new URL(request.url);
  try {
    if (url.pathname === "/v1/chunks") {
      const keys = parseChunkKeysFromUrl(url);
      const chunks = await api.getChunks(keys);
      return jsonResponse(200, { schemaVersion: "explorer-v1", chunks });
    }

    if (url.pathname.startsWith("/v1/hex/")) {
      const hexCoordinate = parseHexCoordinateFromPath(url.pathname);
      const payload = await api.getHex(hexCoordinate);
      return jsonResponse(200, payload);
    }

    if (url.pathname === "/v1/search") {
      const query = parseSearchQueryFromUrl(url);
      const results = await api.search(query);
      return jsonResponse(200, { schemaVersion: "explorer-v1", results });
    }

    if (url.pathname === "/v1/status") {
      const status = await api.status();
      return jsonResponse(200, status);
    }
  } catch (error) {
    return jsonResponse(400, {
      error: error instanceof Error ? error.message : "bad request"
    });
  }

  return jsonResponse(404, { error: "route not found" });
}

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: JSON_HEADERS
  });
}
