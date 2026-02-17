import type { ViewportWindow } from "@gen-dungeon/explorer-types";
import type { RendererCameraConfig } from "./contracts.js";

export interface CameraPoint {
  x: number;
  y: number;
}

export interface CameraState {
  center: CameraPoint;
  zoom: number;
  rotationRad: number;
  tiltRad: number;
}

export function createCameraState(
  config: RendererCameraConfig,
  center: CameraPoint = { x: 0, y: 0 }
): CameraState {
  return {
    center,
    zoom: clamp(config.initialZoom, config.minZoom, config.maxZoom),
    rotationRad: 0,
    tiltRad: 0
  };
}

export function panCamera(
  state: CameraState,
  deltaX: number,
  deltaY: number
): CameraState {
  return {
    ...state,
    center: {
      x: state.center.x + deltaX,
      y: state.center.y + deltaY
    }
  };
}

export function setCameraZoom(
  state: CameraState,
  zoom: number,
  config: Pick<RendererCameraConfig, "minZoom" | "maxZoom">
): CameraState {
  return {
    ...state,
    zoom: clamp(zoom, config.minZoom, config.maxZoom)
  };
}

export function applyRotationOrTilt(
  state: CameraState,
  _rotationDeltaRad: number,
  _tiltDeltaRad: number
): CameraState {
  return {
    ...state,
    rotationRad: 0,
    tiltRad: 0
  };
}

export function worldToScreen(
  state: CameraState,
  world: CameraPoint,
  viewportWidthPx: number,
  viewportHeightPx: number
): CameraPoint {
  return {
    x: (world.x - state.center.x) * state.zoom + viewportWidthPx / 2,
    y: (world.y - state.center.y) * state.zoom + viewportHeightPx / 2
  };
}

export function screenToWorld(
  state: CameraState,
  screen: CameraPoint,
  viewportWidthPx: number,
  viewportHeightPx: number
): CameraPoint {
  return {
    x: (screen.x - viewportWidthPx / 2) / state.zoom + state.center.x,
    y: (screen.y - viewportHeightPx / 2) / state.zoom + state.center.y
  };
}

export function toViewportWindow(
  state: CameraState,
  viewportWidthPx: number,
  viewportHeightPx: number
): ViewportWindow {
  return {
    center: state.center,
    width: viewportWidthPx,
    height: viewportHeightPx,
    zoom: state.zoom
  };
}

function clamp(value: number, min: number, max: number): number {
  if (value < min) {
    return min;
  }

  if (value > max) {
    return max;
  }

  return value;
}
