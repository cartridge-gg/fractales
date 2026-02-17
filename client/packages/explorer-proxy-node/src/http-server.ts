import { createServer, type IncomingMessage, type Server, type ServerResponse } from "node:http";
import WebSocket, { WebSocketServer } from "ws";
import type { ExplorerProxyApi, ExplorerProxyStream } from "./contracts.js";
import { handleExplorerProxyHttpRequest } from "./http-routes.js";

export interface StartExplorerProxyHttpServerOptions {
  api: ExplorerProxyApi;
  stream?: ExplorerProxyStream;
  host?: string;
  port?: number;
  signal?: AbortSignal;
}

export interface ExplorerProxyHttpServer {
  origin: string;
  host: string;
  port: number;
  close(): Promise<void>;
}

const DEFAULT_HOST = "127.0.0.1";
const DEFAULT_PORT = 3001;

export async function startExplorerProxyHttpServer(
  options: StartExplorerProxyHttpServerOptions
): Promise<ExplorerProxyHttpServer> {
  const host = options.host ?? DEFAULT_HOST;
  const port = options.port ?? DEFAULT_PORT;
  const stream = options.stream ?? null;
  const websocketServer = new WebSocketServer({ noServer: true });

  const server = createServer((req, res) => {
    const corsHeaders = buildCorsHeaders(req);
    if ((req.method ?? "GET").toUpperCase() === "OPTIONS") {
      writeCorsHeaders(res, corsHeaders);
      res.statusCode = 204;
      res.end();
      return;
    }

    void handleNodeRequest(options.api, req, host, port)
      .then((response) => writeNodeResponse(res, response, corsHeaders))
      .catch((error) => {
        const message = error instanceof Error ? error.message : "internal error";
        res.statusCode = 500;
        writeCorsHeaders(res, corsHeaders);
        res.setHeader("content-type", "application/json; charset=utf-8");
        res.end(JSON.stringify({ error: message }));
      });
  });
  server.on("upgrade", (req, socket, head) => {
    if (!isStreamUpgradeRequest(req, host, port)) {
      socket.write("HTTP/1.1 404 Not Found\r\n\r\n");
      socket.destroy();
      return;
    }

    if (!stream) {
      socket.write("HTTP/1.1 503 Service Unavailable\r\n\r\n");
      socket.destroy();
      return;
    }

    websocketServer.handleUpgrade(req, socket, head, (websocket: WebSocket) => {
      const unsubscribe = stream.subscribe((patch) => {
        if (websocket.readyState !== WebSocket.OPEN) {
          return;
        }
        websocket.send(JSON.stringify(patch));
      });

      websocket.on("close", () => {
        unsubscribe();
      });
      websocket.on("error", () => {
        unsubscribe();
      });
    });
  });

  await listen(server, host, port);

  const address = server.address();
  if (!address || typeof address === "string") {
    throw new Error("failed to resolve proxy bind address");
  }

  let closed = false;
  const close = async (): Promise<void> => {
    if (closed) {
      return;
    }
    closed = true;
    await closeWebSocketServer(websocketServer);
    await closeServer(server);
  };

  if (options.signal) {
    if (options.signal.aborted) {
      await close();
    } else {
      options.signal.addEventListener("abort", () => {
        void close();
      });
    }
  }

  return {
    origin: `http://${host}:${address.port}`,
    host,
    port: address.port,
    close
  };
}

function isStreamUpgradeRequest(
  req: IncomingMessage,
  fallbackHost: string,
  fallbackPort: number
): boolean {
  const hostHeader = req.headers.host ?? `${fallbackHost}:${fallbackPort}`;
  const url = new URL(req.url ?? "/", `http://${hostHeader}`);
  return url.pathname === "/v1/stream";
}

async function handleNodeRequest(
  api: ExplorerProxyApi,
  req: IncomingMessage,
  fallbackHost: string,
  fallbackPort: number
): Promise<Response> {
  const hostHeader = req.headers.host ?? `${fallbackHost}:${fallbackPort}`;
  const url = new URL(req.url ?? "/", `http://${hostHeader}`);
  const method = req.method ?? "GET";

  const headers = new Headers();
  for (const [name, value] of Object.entries(req.headers)) {
    if (value === undefined) {
      continue;
    }
    if (Array.isArray(value)) {
      for (const row of value) {
        headers.append(name, row);
      }
      continue;
    }
    headers.set(name, value);
  }

  const requestInit: RequestInit = {
    method,
    headers
  };

  const request = new Request(url, requestInit);

  return handleExplorerProxyHttpRequest(api, request);
}

async function writeNodeResponse(
  res: ServerResponse,
  response: Response,
  corsHeaders: Headers
): Promise<void> {
  res.statusCode = response.status;
  writeCorsHeaders(res, corsHeaders);

  response.headers.forEach((value, key) => {
    if (key.toLowerCase() === "transfer-encoding") {
      return;
    }
    res.setHeader(key, value);
  });

  const body = Buffer.from(await response.arrayBuffer());
  res.end(body);
}

function buildCorsHeaders(req: IncomingMessage): Headers {
  const requested = req.headers["access-control-request-headers"];
  const requestHeaders = Array.isArray(requested)
    ? requested.join(", ")
    : requested;

  const headers = new Headers();
  headers.set("access-control-allow-origin", "*");
  headers.set("access-control-allow-methods", "GET, OPTIONS");
  headers.set(
    "access-control-allow-headers",
    requestHeaders?.trim() || "accept, content-type"
  );
  headers.set("access-control-max-age", "86400");
  return headers;
}

function writeCorsHeaders(res: ServerResponse, headers: Headers): void {
  headers.forEach((value, key) => {
    res.setHeader(key, value);
  });
}

function listen(server: Server, host: string, port: number): Promise<void> {
  return new Promise((resolve, reject) => {
    const onError = (error: Error): void => {
      server.off("listening", onListening);
      reject(error);
    };
    const onListening = (): void => {
      server.off("error", onError);
      resolve();
    };
    server.once("error", onError);
    server.once("listening", onListening);
    server.listen(port, host);
  });
}

function closeServer(server: Server): Promise<void> {
  return new Promise((resolve, reject) => {
    server.close((error: Error | undefined) => {
      if (error) {
        reject(error);
        return;
      }
      resolve();
    });
  });
}

function closeWebSocketServer(server: WebSocketServer): Promise<void> {
  return new Promise((resolve, reject) => {
    for (const client of server.clients) {
      client.close();
    }
    server.close((error) => {
      if (error) {
        reject(error);
        return;
      }
      resolve();
    });
  });
}
