import { beforeEach, describe, expect, it, vi } from "vitest";

// svg-pan-zoom needs real layout, so stand in for it.
const { svgPanZoom, zoom } = vi.hoisted(() => {
  const zoom = { zoomIn: vi.fn(), zoomOut: vi.fn(), reset: vi.fn(), resize: vi.fn() };
  return { zoom, svgPanZoom: vi.fn(() => zoom) };
});

vi.mock("svg-pan-zoom", () => ({ default: svgPanZoom }));

import { panZoom } from "../js/pan-zoom.js";

// A diagram's container holding its rendered SVG.
function diagram() {
  const container = document.createElement("pre");
  container.innerHTML = '<svg viewBox="0 0 10 10"></svg>';
  document.body.replaceChildren(container);
  return { container, svg: container.querySelector("svg")! };
}

const button = (container: Element, label: string) =>
  container.querySelector<HTMLButtonElement>(`.diagram-controls button[aria-label="${label}"]`);

beforeEach(() => {
  svgPanZoom.mockClear();
  Object.values(zoom).forEach((fn) => fn.mockClear());
});

describe("panZoom", () => {
  it("pans and zooms the SVG without svg-pan-zoom's own controls", () => {
    const { container, svg } = diagram();

    expect(panZoom(container, svg)).toBe(zoom);
    expect(svgPanZoom).toHaveBeenCalledWith(svg, expect.objectContaining({ controlIconsEnabled: false }));
  });

  it("adds named buttons, with hover hints, that zoom in, zoom out and fit the diagram", () => {
    const { container, svg } = diagram();
    panZoom(container, svg);

    for (const [label, action] of [
      ["Zoom in", zoom.zoomIn],
      ["Zoom out", zoom.zoomOut],
      ["Fit to view", zoom.reset],
    ] as const) {
      const control = button(container, label)!;
      expect(control.dataset.tooltipText).toBe(label);
      control.click();
      expect(action).toHaveBeenCalledOnce();
    }
  });

  it("keeps one set of controls when the diagram renders again", () => {
    const { container, svg } = diagram();

    panZoom(container, svg);
    panZoom(container, svg);

    expect(container.querySelectorAll(".diagram-controls")).toHaveLength(1);
  });
});
