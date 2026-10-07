import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import NavPanel, { applyNavState, MIN_WIDTH } from "../js/nav-panel.hook.js";

const root = document.documentElement;
const width = () => root.style.getPropertyValue("--clarity-nav-width");
const collapsed = () => root.classList.contains("clarity-nav-collapsed");

function mount(navWidth = 320) {
  document.body.innerHTML = `
    <nav class="navigation"></nav>
    <div id="nav-resize" tabindex="0"></div>
    <input id="search" />
  `;
  const nav = document.querySelector(".navigation") as HTMLElement;
  nav.getBoundingClientRect = () => ({ width: navWidth }) as DOMRect;
  const el = document.getElementById("nav-resize")!;
  const hook = Object.assign(Object.create(NavPanel), { el });
  hook.mounted();
  return hook;
}

const pointer = (type: string, clientX: number, target: EventTarget = document) =>
  target.dispatchEvent(new MouseEvent(type, { bubbles: true, clientX }));

describe("nav-panel.hook", () => {
  let hook: ReturnType<typeof mount>;

  beforeEach(() => {
    localStorage.clear();
    root.style.removeProperty("--clarity-nav-width");
    root.classList.remove("clarity-nav-collapsed");
    vi.stubGlobal("innerWidth", 1600);
  });

  afterEach(() => {
    hook?.destroyed();
    vi.unstubAllGlobals();
  });

  describe("applyNavState", () => {
    it("restores the saved width and collapsed state", () => {
      localStorage.setItem("clarity:nav-width", "400");
      localStorage.setItem("clarity:nav-collapsed", "true");

      applyNavState();

      expect(width()).toBe("400px");
      expect(collapsed()).toBe(true);
    });

    it("leaves the default layout when nothing is saved", () => {
      applyNavState();

      expect(width()).toBe("");
      expect(collapsed()).toBe(false);
    });
  });

  it("resizes the panel by dragging its edge, and remembers the width", () => {
    hook = mount(320);

    pointer("pointerdown", 320, hook.el);
    pointer("pointermove", 400);
    pointer("pointerup", 400);

    expect(width()).toBe("400px");
    expect(localStorage.getItem("clarity:nav-width")).toBe("400");
  });

  it("keeps the width within bounds", () => {
    hook = mount(320);

    pointer("pointerdown", 320, hook.el);
    pointer("pointermove", 0);
    pointer("pointerup", 0);

    expect(width()).toBe(`${MIN_WIDTH}px`);
  });

  it("resizes with the arrow keys", () => {
    hook = mount(320);

    hook.el.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true }));

    expect(width()).toBe("336px");
  });

  it("resets to the default width on double click", () => {
    localStorage.setItem("clarity:nav-width", "400");
    hook = mount(400);

    hook.el.dispatchEvent(new MouseEvent("dblclick", { bubbles: true }));

    expect(width()).toBe("");
    expect(localStorage.getItem("clarity:nav-width")).toBeNull();
  });

  it("collapses and expands from the sidebar toggle, and remembers it", () => {
    hook = mount();

    window.dispatchEvent(new Event("clarity:toggle-nav"));

    expect(collapsed()).toBe(true);
    expect(localStorage.getItem("clarity:nav-collapsed")).toBe("true");

    window.dispatchEvent(new Event("clarity:toggle-nav"));

    expect(collapsed()).toBe(false);
  });

  it("toggles with Cmd/Ctrl+B, except while typing", () => {
    hook = mount();

    document.dispatchEvent(new KeyboardEvent("keydown", { key: "b", metaKey: true }));
    expect(collapsed()).toBe(true);

    document.dispatchEvent(new KeyboardEvent("keydown", { key: "b", ctrlKey: true }));
    expect(collapsed()).toBe(false);

    document
      .getElementById("search")!
      .dispatchEvent(new KeyboardEvent("keydown", { key: "b", metaKey: true, bubbles: true }));
    expect(collapsed()).toBe(false);
  });
});
