import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import Details from "../js/details.hook.js";

// Mirrors the navigation tree: a node whose summary holds a chevron and a
// label link, with a nested node rendered inside its content.
const TREE = `
  <details id="outer" phx-hook="Details" phx-toggle="toggle" phx-value-vertex_id="outer">
    <summary>
      <svg class="tree-chevron"></svg>
      <a href="/lens/outer" data-phx-link="patch">outer</a>
    </summary>
    <div>
      <details id="inner" phx-hook="Details" phx-toggle="toggle" phx-value-vertex_id="inner">
        <summary>
          <svg class="tree-chevron"></svg>
          <a href="/lens/inner" data-phx-link="patch">inner</a>
        </summary>
      </details>
    </div>
  </details>
`;

function mount(el: HTMLElement) {
  const hook = Object.assign(Object.create(Details), {
    el,
    pushEventTo: vi.fn(),
  });
  hook.mounted();
  return hook;
}

function click(el: Element) {
  const event = new MouseEvent("click", { bubbles: true, cancelable: true });
  el.dispatchEvent(event);
  return event;
}

describe("details.hook", () => {
  let outer: HTMLDetailsElement;
  let inner: HTMLDetailsElement;
  let outerHook: ReturnType<typeof mount>;
  let innerHook: ReturnType<typeof mount>;
  // Stands in for LiveView's window click handler, which takes over patch
  // links and prevents their default action.
  let liveView: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    liveView = vi.fn((event: Event) => {
      if ((event.target as Element).closest("[data-phx-link]")) event.preventDefault();
    });
    window.addEventListener("click", liveView);
    document.body.innerHTML = TREE;
    outer = document.getElementById("outer") as HTMLDetailsElement;
    inner = document.getElementById("inner") as HTMLDetailsElement;
    outerHook = mount(outer);
    innerHook = mount(inner);
  });

  afterEach(() => {
    window.removeEventListener("click", liveView);
    document.body.innerHTML = "";
  });

  const chevron = (node: HTMLElement) => node.querySelector(":scope > summary > .tree-chevron")!;
  const label = (node: HTMLElement) => node.querySelector(":scope > summary > a")!;

  it("opens the node from its chevron and reports the new state", () => {
    click(chevron(outer));

    expect(outer.open).toBe(true);
    expect(outerHook.pushEventTo).toHaveBeenCalledExactlyOnceWith(outer, "toggle", {
      vertex_id: "outer",
      open: true,
    });
  });

  it("closes an open node from its chevron and reports the new state", () => {
    outer.open = true;

    click(chevron(outer));

    expect(outer.open).toBe(false);
    expect(outerHook.pushEventTo).toHaveBeenCalledExactlyOnceWith(outer, "toggle", {
      vertex_id: "outer",
      open: false,
    });
  });

  it("reports a click in a nested node for that node only", () => {
    outer.open = true;

    click(chevron(inner));

    expect(innerHook.pushEventTo).toHaveBeenCalledExactlyOnceWith(inner, "toggle", {
      vertex_id: "inner",
      open: true,
    });
    expect(outerHook.pushEventTo).not.toHaveBeenCalled();
    expect(outer.open).toBe(true);
  });

  it("leaves a label that navigates elsewhere to LiveView", () => {
    click(label(outer));

    expect(liveView).toHaveBeenCalledOnce();
    expect(outerHook.pushEventTo).not.toHaveBeenCalled();
  });

  it("toggles the current node from its label, like the chevron", () => {
    label(outer).setAttribute("aria-current", "page");

    click(label(outer));

    expect(liveView).not.toHaveBeenCalled();
    expect(outer.open).toBe(true);

    click(label(outer));

    expect(outer.open).toBe(false);
    expect(outerHook.pushEventTo.mock.calls).toEqual([
      [outer, "toggle", { vertex_id: "outer", open: true }],
      [outer, "toggle", { vertex_id: "outer", open: false }],
    ]);
  });

  it("does not report opens and closes made by a LiveView patch", async () => {
    // A navigation click inside the subtree used to arm the ancestor, so the
    // patch that followed was sent back as a toggle of the wrong node.
    outer.open = true;
    click(label(inner));

    outer.open = false;
    outer.dispatchEvent(new Event("toggle"));
    inner.open = true;
    inner.dispatchEvent(new Event("toggle"));
    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(outerHook.pushEventTo).not.toHaveBeenCalled();
    expect(innerHook.pushEventTo).not.toHaveBeenCalled();
  });
});
