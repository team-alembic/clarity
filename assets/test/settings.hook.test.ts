import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import Settings, { getLinking, MENU_GAP } from "../js/settings.hook.js";

// A system theme whose changes the test can fire.
function stubSystem(dark: boolean) {
  const listeners = new Set<() => void>();
  const scheme = {
    matches: dark,
    addEventListener: (_type: string, listener: () => void) => listeners.add(listener),
    removeEventListener: (_type: string, listener: () => void) => listeners.delete(listener),
  };
  vi.stubGlobal("matchMedia", vi.fn().mockReturnValue(scheme));

  return (nowDark: boolean) => {
    scheme.matches = nowDark;
    listeners.forEach((listener) => listener());
  };
}

function mount() {
  const el = document.createElement("div");
  el.innerHTML = `
    <button type="button" popovertarget="menu">Settings</button>
    <div id="menu" popover>
      <input type="radio" name="theme" value="light" />
      <input type="radio" name="theme" value="dark" />
      <input type="radio" name="theme" value="system" />
      <input type="checkbox" name="lowercase" data-linking />
      <input type="checkbox" name="every" data-linking />
    </div>
  `;
  document.body.append(el);

  const hook = Object.assign(Object.create(Settings), { el, pushEvent: vi.fn() });
  hook.mounted();
  return hook;
}

function choose(hook: { el: HTMLElement }, selector: string, checked = true) {
  const input = hook.el.querySelector<HTMLInputElement>(selector)!;
  input.checked = checked;
  input.dispatchEvent(new Event("change", { bubbles: true }));
}

const checked = (hook: { el: HTMLElement }, selector: string) =>
  hook.el.querySelector<HTMLInputElement>(selector)!.checked;

describe("Settings", () => {
  let hook: ReturnType<typeof mount> | null = null;

  beforeEach(() => {
    localStorage.clear();
    document.documentElement.classList.remove("dark");
    stubSystem(false);
  });

  afterEach(() => {
    hook?.destroyed();
    hook?.el.remove();
    hook = null;
    vi.unstubAllGlobals();
  });

  it("shows the defaults: the system theme, lowercase names linked, each first mention", () => {
    hook = mount();

    expect(checked(hook, 'input[value="system"]')).toBe(true);
    expect(checked(hook, 'input[name="lowercase"]')).toBe(true);
    expect(checked(hook, 'input[name="every"]')).toBe(false);
  });

  it("shows the stored settings", () => {
    localStorage.setItem("clarity-theme", "dark");
    localStorage.setItem("clarity-link-lowercase", "false");
    localStorage.setItem("clarity-link-every", "true");
    hook = mount();

    expect(checked(hook, 'input[value="dark"]')).toBe(true);
    expect(checked(hook, 'input[name="lowercase"]')).toBe(false);
    expect(checked(hook, 'input[name="every"]')).toBe(true);
  });

  it("applies, stores and reports a chosen theme", () => {
    hook = mount();
    choose(hook, 'input[value="dark"]');

    expect(document.documentElement.classList.contains("dark")).toBe(true);
    expect(localStorage.getItem("clarity-theme")).toBe("dark");
    expect(hook.pushEvent).toHaveBeenCalledWith("set-theme", { theme: "dark" });
  });

  it("reports the system's theme when the viewer chooses to follow it", () => {
    stubSystem(true);
    localStorage.setItem("clarity-theme", "light");
    hook = mount();
    choose(hook, 'input[value="system"]');

    expect(localStorage.getItem("clarity-theme")).toBeNull();
    expect(hook.pushEvent).toHaveBeenCalledWith("set-theme", { theme: "dark" });
  });

  it("follows the system's theme as it changes, only while following it", () => {
    const changeSystem = stubSystem(false);
    hook = mount();

    changeSystem(true);
    expect(document.documentElement.classList.contains("dark")).toBe(true);
    expect(hook.pushEvent).toHaveBeenLastCalledWith("set-theme", { theme: "dark" });

    choose(hook, 'input[value="light"]');
    changeSystem(true);
    expect(document.documentElement.classList.contains("dark")).toBe(false);
  });

  it("stops following the system once destroyed", () => {
    const changeSystem = stubSystem(false);
    hook = mount();
    hook.destroyed();

    changeSystem(true);
    expect(hook.pushEvent).not.toHaveBeenCalled();
  });

  it("stores and reports each text linking option", () => {
    hook = mount();
    choose(hook, 'input[name="lowercase"]', false);
    choose(hook, 'input[name="every"]');

    expect(getLinking()).toEqual({ lowercase: false, every: true });
    expect(hook.pushEvent).toHaveBeenCalledWith("set-linking", { lowercase: false });
    expect(hook.pushEvent).toHaveBeenCalledWith("set-linking", { every: true });
  });

  it("hangs the menu just below the gear as it opens, their right edges lined up", () => {
    hook = mount();
    vi.stubGlobal("innerWidth", 1280);
    hook.button.getBoundingClientRect = () => ({ bottom: 40, right: 1260 }) as DOMRect;

    hook.menu.dispatchEvent(Object.assign(new Event("beforetoggle"), { newState: "open" }));

    expect(hook.menu.style.top).toBe(`${40 + MENU_GAP}px`);
    expect(hook.menu.style.right).toBe("20px");
  });

  it("leaves the menu where it is as it closes", () => {
    hook = mount();
    hook.button.getBoundingClientRect = () => ({ bottom: 40, right: 1260 }) as DOMRect;

    hook.menu.dispatchEvent(Object.assign(new Event("beforetoggle"), { newState: "closed" }));

    expect(hook.menu.style.top).toBe("");
  });
});
