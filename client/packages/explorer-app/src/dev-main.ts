import { createExplorerApp } from "./app.js";
import type { ExplorerUiBindings } from "./contracts.js";
import { createDevRuntime } from "./dev-runtime.js";
import { renderInspectPanelHtml } from "./inspect-format.js";
import {
  createLiveToriiRuntime,
  DEFAULT_LIVE_TORII_GRAPHQL_URL
} from "./live-runtime.js";
import "./dev.css";

const canvas = getRequiredElement<HTMLCanvasElement>("#explorer-canvas");
const statusPill = getRequiredElement<HTMLSpanElement>("#status-pill");
const urlLabel = getRequiredElement<HTMLElement>("#url-label");
const inspectSelected = getRequiredElement<HTMLElement>("#inspect-selected");
const inspectLayout = getRequiredElement<HTMLElement>("#inspect-layout");
const inspectDetails = getRequiredElement<HTMLElement>("#inspect-details");
const visibleList = getRequiredElement<HTMLOListElement>("#visible-list");
const snapshotLine = getRequiredElement<HTMLElement>("#snapshot-line");
const searchResults = getRequiredElement<HTMLUListElement>("#search-results");
const routeInput = getRequiredElement<HTMLInputElement>("#route-input");
const searchMode = getRequiredElement<HTMLSelectElement>("#search-mode");
const searchInput = getRequiredElement<HTMLInputElement>("#search-input");
const viewportGrid = getRequiredElement<HTMLElement>(".viewport-grid");
const controlsToggle = getRequiredElement<HTMLButtonElement>("#controls-toggle");
const controlGrid = getRequiredElement<HTMLElement>("#control-grid");

const params = new URLSearchParams(window.location.search);
const runtimeMode = params.get("source") === "mock" ? "mock" : "live";
const liveToriiGraphqlUrl = params.get("torii") ?? DEFAULT_LIVE_TORII_GRAPHQL_URL;
const runtime =
  runtimeMode === "mock"
    ? createDevRuntime(canvas)
    : createLiveToriiRuntime(canvas, {
        toriiGraphqlUrl: liveToriiGraphqlUrl
      });
const routeBasePath = runtimeMode === "mock" ? "/explorer/mock" : "/explorer/live";
urlLabel.textContent = routeBasePath;
routeInput.value = routeBasePath;

const ui: ExplorerUiBindings = {
  setConnectionStatus(status) {
    statusPill.textContent = status.replace("_", " ");
    statusPill.className = `status-pill ${status}`;
  },
  setLayerState(state) {
    for (const layerInput of Array.from(document.querySelectorAll<HTMLInputElement>("[data-layer]"))) {
      const layer = layerInput.dataset.layer;
      if (!layer) {
        continue;
      }
      const enabled = state[layer as keyof typeof state];
      if (typeof enabled === "boolean") {
        layerInput.checked = enabled;
      }
    }
  },
  setSelectedHex(hexCoordinate) {
    inspectSelected.textContent = `selected: ${hexCoordinate ?? "none"}`;
  },
  setInspectPayload(payload) {
    inspectDetails.innerHTML = renderInspectPanelHtml(payload);
  },
  setSearchResults(results) {
    searchResults.innerHTML = "";
    for (const result of results) {
      const item = document.createElement("li");
      item.textContent = `${result.label}`;
      searchResults.append(item);
    }
  }
};

const app = createExplorerApp(runtime.dependencies, {
  ui,
  routeBasePath
});

let rafId = 0;
try {
  await app.mount();
  await fitDesktopCanvas();
  syncSnapshot();

  const draw = (nowMs: number) => {
    runtime.renderer.renderFrame(nowMs);
    syncSnapshot();
    rafId = window.requestAnimationFrame(draw);
  };
  rafId = window.requestAnimationFrame(draw);
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  statusPill.textContent = "degraded";
  statusPill.className = "status-pill degraded";
  inspectSelected.textContent = `mount error: ${message}`;
  console.error("explorer-app mount failed", error);
}

for (const button of Array.from(document.querySelectorAll<HTMLButtonElement>("[data-pan]"))) {
  button.addEventListener("click", async () => {
    const raw = button.dataset.pan;
    if (!raw) {
      return;
    }
    const [xRaw, yRaw] = raw
      .split(",")
      .map((value: string) => Number.parseFloat(value));
    const x = xRaw ?? 0;
    const y = yRaw ?? 0;
    await app.panBy(x, y);
    syncSnapshot();
  });
}

getRequiredElement<HTMLButtonElement>("#zoom-in").addEventListener("click", async () => {
  const current = app.snapshot().viewport.zoom;
  await app.zoomTo(current + 0.2);
  syncSnapshot();
});

getRequiredElement<HTMLButtonElement>("#zoom-out").addEventListener("click", async () => {
  const current = app.snapshot().viewport.zoom;
  await app.zoomTo(current - 0.2);
  syncSnapshot();
});

async function runSearch(): Promise<void> {
  const mode = searchMode.value;
  const value = searchInput.value.trim();
  if (!value) {
    return;
  }

  if (mode === "coord") {
    await app.jumpTo({ coord: value });
  } else if (mode === "owner") {
    await app.jumpTo({ owner: value });
  } else {
    await app.jumpTo({ adventurer: value });
  }
  syncSnapshot();
}

getRequiredElement<HTMLButtonElement>("#search-run").addEventListener("click", () => {
  void runSearch();
});

searchInput.addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    event.preventDefault();
    void runSearch();
  }
});

searchMode.addEventListener("change", () => {
  if (searchMode.value === "coord") {
    searchInput.placeholder = "0x200";
  } else if (searchMode.value === "owner") {
    searchInput.placeholder = "0xowner0";
  } else {
    searchInput.placeholder = "0xadv0";
  }
});

for (const button of Array.from(document.querySelectorAll<HTMLButtonElement>("[data-status]"))) {
  button.addEventListener("click", async () => {
    const status = button.dataset.status;
    if (status === "live" || status === "catching_up" || status === "degraded") {
      await app.updateStreamStatus(status);
      syncSnapshot();
    }
  });
}

for (const layerInput of Array.from(document.querySelectorAll<HTMLInputElement>("[data-layer]"))) {
  layerInput.addEventListener("change", () => {
    const layer = layerInput.dataset.layer;
    if (!layer) {
      return;
    }
    app.setLayerToggle(layer as Parameters<typeof app.setLayerToggle>[0], layerInput.checked);
    syncSnapshot();
  });
}

getRequiredElement<HTMLButtonElement>("#layers-on").addEventListener("click", () => {
  app.setAllLayers(true);
  syncSnapshot();
});

getRequiredElement<HTMLButtonElement>("#layers-off").addEventListener("click", () => {
  app.setAllLayers(false);
  syncSnapshot();
});

async function hydrateRoute(): Promise<void> {
  const value = routeInput.value.trim();
  if (!value) {
    return;
  }
  await app.hydrateFromUrl(value);
  syncSnapshot();
}

getRequiredElement<HTMLButtonElement>("#route-hydrate").addEventListener("click", () => {
  void hydrateRoute();
});

routeInput.addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    event.preventDefault();
    void hydrateRoute();
  }
});

getRequiredElement<HTMLButtonElement>("#mobile-layout").addEventListener("click", async () => {
  await app.resize(390, 844, 2);
  syncSnapshot();
});

getRequiredElement<HTMLButtonElement>("#desktop-layout").addEventListener("click", async () => {
  await fitDesktopCanvas();
  syncSnapshot();
});

window.addEventListener("resize", () => {
  void fitDesktopCanvas();
});

window.addEventListener("beforeunload", () => {
  cleanup();
});

// --- Collapsible controls ---
controlsToggle.addEventListener("click", () => {
  const collapsed = controlGrid.classList.toggle("is-collapsed");
  controlsToggle.classList.toggle("is-collapsed", collapsed);
});

// --- Inspect scroll fade indicator ---
function updateScrollFade(): void {
  let fade = inspectDetails.querySelector<HTMLElement>(".inspect-scroll-fade");
  if (!fade) {
    fade = document.createElement("div");
    fade.className = "inspect-scroll-fade";
    inspectDetails.append(fade);
  }
  const hasOverflow = inspectDetails.scrollHeight > inspectDetails.clientHeight + 4;
  const atBottom = inspectDetails.scrollTop + inspectDetails.clientHeight >= inspectDetails.scrollHeight - 4;
  fade.classList.toggle("is-visible", hasOverflow && !atBottom);
}

inspectDetails.addEventListener("scroll", updateScrollFade);

const inspectObserver = new MutationObserver(updateScrollFade);
inspectObserver.observe(inspectDetails, { childList: true, subtree: true });

function syncSnapshot(): void {
  const snapshot = app.snapshot();
  inspectLayout.textContent = `layout: ${snapshot.layout}`;
  urlLabel.textContent = snapshot.url;
  routeInput.value = snapshot.url;
  snapshotLine.textContent =
    `selected: ${snapshot.selectedHex ?? "none"} | ` +
    `visible: ${snapshot.visibleHexes.length} | ` +
    `zoom: ${snapshot.viewport.zoom.toFixed(2)}`;

  visibleList.innerHTML = "";
  for (const hex of snapshot.visibleHexes.slice(0, 18)) {
    const item = document.createElement("li");
    item.textContent = hex.hexCoordinate;
    visibleList.append(item);
  }
}

async function fitDesktopCanvas(): Promise<void> {
  const viewportWidth = Math.max(640, Math.floor(viewportGrid.clientWidth - 332));
  const viewportHeight = Math.max(420, Math.floor(window.innerHeight * 0.66));
  await app.resize(viewportWidth, viewportHeight, window.devicePixelRatio || 1);
}

function cleanup(): void {
  window.cancelAnimationFrame(rafId);
  app.unmount();
}

function getRequiredElement<TElement extends Element>(selector: string): TElement {
  const element = document.querySelector<TElement>(selector);
  if (!element) {
    throw new Error(`Missing required element: ${selector}`);
  }
  return element;
}
