import { beforeEach, describe, expect, it, vi } from "vitest";

// Mermaid and svg-pan-zoom need real layout, so stand in for both.
const { svgPanZoom } = vi.hoisted(() => ({
  svgPanZoom: vi.fn(() => ({ resize: vi.fn() })),
}));

vi.mock("svg-pan-zoom", () => ({ default: svgPanZoom }));
vi.mock("mermaid", () => ({
  default: {
    initialize: vi.fn(),
    render: vi.fn(async () => ({ svg: '<svg viewBox="0 0 10 10"></svg>' })),
  },
}));

import Mermaid from "../js/mermaid.hook.js";

// A hook on a <pre> holding a diagram, with the given data attributes.
function hookFor(id: string, data: Record<string, string> = {}) {
  const el = document.createElement("pre");
  el.id = id;
  Object.assign(el.dataset, { graph: "stateDiagram-v2\n  [*] --> a" }, data);
  return Object.assign(Object.create(Mermaid), { el });
}

beforeEach(() => svgPanZoom.mockClear());

describe("render", () => {
  it("lets the user pan and zoom a diagram", async () => {
    const hook = hookFor("pannable");

    await hook.render();

    expect(svgPanZoom).toHaveBeenCalledOnce();
    expect(hook.el.querySelector("svg").getAttribute("preserveAspectRatio")).toBe("xMidYMid slice");
  });

  it("fits a diagram that opts out of pan and zoom to its box", async () => {
    const hook = hookFor("fitted", { panZoom: "false" });

    await hook.render();

    expect(svgPanZoom).not.toHaveBeenCalled();
    expect(hook.el.querySelector("svg").getAttribute("preserveAspectRatio")).toBe("xMidYMid meet");
  });
});
