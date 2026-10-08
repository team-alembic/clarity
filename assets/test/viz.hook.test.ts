import { beforeEach, describe, expect, it, vi } from "vitest";

// Graphviz and svg-pan-zoom need WebAssembly and real layout, so stand in
// for both: the graph renders as one linked node.
const { svgPanZoom } = vi.hoisted(() => ({
  svgPanZoom: vi.fn(() => ({ resize: vi.fn() })),
}));

vi.mock("svg-pan-zoom", () => ({ default: svgPanZoom }));
vi.mock("@viz-js/viz", () => ({
  instance: async () => ({
    renderSVGElement: () =>
      new DOMParser().parseFromString(
        '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="80pt" height="40pt"><a xlink:href="#ash-attribute:demo-x:y"><text>y</text></a></svg>',
        "image/svg+xml",
      ).documentElement,
  }),
}));

import Viz from "../js/viz.hook.js";

// A hook on a <pre> holding a graph, with the given data attributes.
function hookFor(id: string, data: Record<string, string> = {}) {
  const el = document.createElement("pre");
  el.id = id;
  Object.assign(el.dataset, { graph: `digraph { "${id}" }` }, data);
  return Object.assign(Object.create(Viz), { el, pushEvent: vi.fn() });
}

beforeEach(() => svgPanZoom.mockClear());

describe("render", () => {
  it("lets the user pan and zoom a graph, and opens a clicked vertex in the graph", async () => {
    const hook = hookFor("pannable");

    await hook.render();
    hook.el.querySelector("a").dispatchEvent(new MouseEvent("click", { bubbles: true }));

    expect(svgPanZoom).toHaveBeenCalledOnce();
    expect(hook.el.querySelector("svg").getAttribute("width")).toBe("100%");
    expect(hook.pushEvent).toHaveBeenCalledWith("viz:click", { id: "ash-attribute:demo-x:y" });
  });

  it("keeps a diagram among sections at its own size, and sends its own event", async () => {
    const hook = hookFor("fixed", { panZoom: "false", event: "viz:open" });

    await hook.render();
    hook.el.querySelector("a").dispatchEvent(new MouseEvent("click", { bubbles: true }));

    const svg = hook.el.querySelector("svg");
    expect(svgPanZoom).not.toHaveBeenCalled();
    expect(svg.getAttribute("width")).toBe("80pt");
    expect(svg.style.maxWidth).toBe("100%");
    expect(hook.pushEvent).toHaveBeenCalledWith("viz:open", { id: "ash-attribute:demo-x:y" });
  });
});
