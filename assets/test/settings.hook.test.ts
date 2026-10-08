import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import Settings, { getLinkLowercase } from "../js/settings.hook.js";

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
    <input type="radio" name="theme" value="light" />
    <input type="radio" name="theme" value="dark" />
    <input type="radio" name="theme" value="system" />
    <input type="checkbox" name="link_lowercase" />
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

  it("shows the stored settings, defaulting to the system theme and linking lowercase", () => {
    hook = mount();

    expect(checked(hook, 'input[value="system"]')).toBe(true);
    expect(checked(hook, 'input[name="link_lowercase"]')).toBe(true);
  });

  it("shows a stored theme and lowercase linking turned off", () => {
    localStorage.setItem("clarity-theme", "dark");
    localStorage.setItem("clarity-link-lowercase", "false");
    hook = mount();

    expect(checked(hook, 'input[value="dark"]')).toBe(true);
    expect(checked(hook, 'input[name="link_lowercase"]')).toBe(false);
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

  it("stores and reports lowercase linking", () => {
    hook = mount();
    choose(hook, 'input[name="link_lowercase"]', false);

    expect(getLinkLowercase()).toBe(false);
    expect(hook.pushEvent).toHaveBeenCalledWith("set-link-lowercase", { enabled: false });
  });
});
