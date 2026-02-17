import { describe, expect, it } from "vitest";
import type { RendererCameraConfig } from "../src/contracts.js";
import {
  applyRotationOrTilt,
  createCameraState,
  panCamera,
  screenToWorld,
  setCameraZoom,
  toViewportWindow,
  worldToScreen
} from "../src/camera.js";

const cameraConfig: RendererCameraConfig = {
  minZoom: 0.5,
  maxZoom: 3,
  initialZoom: 1
};

describe("camera constraints (RED)", () => {
  it("camera.top_down_pan_zoom_only.red", () => {
    let state = createCameraState(cameraConfig);
    state = panCamera(state, 12, -4);
    state = applyRotationOrTilt(state, 0.5, 0.25);

    expect(state.center).toEqual({ x: 12, y: -4 });
    expect(state.rotationRad).toBe(0);
    expect(state.tiltRad).toBe(0);
  });

  it("camera.zoom_clamps_to_bounds.red", () => {
    const belowMin = setCameraZoom(createCameraState(cameraConfig), 0.1, cameraConfig);
    const aboveMax = setCameraZoom(createCameraState(cameraConfig), 10, cameraConfig);

    expect(belowMin.zoom).toBe(0.5);
    expect(aboveMax.zoom).toBe(3);
  });

  it("camera.world_screen_round_trip.red", () => {
    const state = setCameraZoom(createCameraState(cameraConfig), 2, cameraConfig);
    const screen = worldToScreen(state, { x: 4, y: -3 }, 800, 600);
    const world = screenToWorld(state, screen, 800, 600);

    expect(world.x).toBeCloseTo(4, 6);
    expect(world.y).toBeCloseTo(-3, 6);
  });

  it("camera.viewport_window_tracks_center_zoom.red", () => {
    let state = createCameraState(cameraConfig);
    state = panCamera(state, -8, 5);
    state = setCameraZoom(state, 2, cameraConfig);

    const viewport = toViewportWindow(state, 1600, 1200);

    expect(viewport.center).toEqual({ x: -8, y: 5 });
    expect(viewport.zoom).toBe(2);
    expect(viewport.width).toBe(1600);
    expect(viewport.height).toBe(1200);
  });
});
