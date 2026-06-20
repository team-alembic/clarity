import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import ThemeToggle, {
  getCurrentTheme,
  getInitialTheme,
  onThemeChange,
} from "../js/theme.hook.js";

// Stub window.matchMedia with a controllable `matches` value. happy-dom's
// built-in implementation does not parse `prefers-color-scheme`, so we drive it
// explicitly per-test.
function stubMatchMedia(matches: boolean) {
  vi.stubGlobal(
    "matchMedia",
    vi.fn().mockReturnValue({
      matches,
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
    }),
  );
}

describe("theme.hook", () => {
  beforeEach(() => {
    localStorage.clear();
    document.documentElement.classList.remove("dark");
    stubMatchMedia(false);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  describe("getInitialTheme", () => {
    it("returns the theme stored in localStorage", () => {
      localStorage.setItem("clarity-theme", "dark");
      expect(getInitialTheme()).toBe("dark");
    });

    it("falls back to the system preference when nothing is stored", () => {
      stubMatchMedia(true);
      expect(getInitialTheme()).toBe("dark");

      stubMatchMedia(false);
      expect(getInitialTheme()).toBe("light");
    });

    it("prefers the stored value over the system preference", () => {
      stubMatchMedia(true);
      localStorage.setItem("clarity-theme", "light");
      expect(getInitialTheme()).toBe("light");
    });
  });

  describe("getCurrentTheme", () => {
    it("reflects the `dark` class on the document element", () => {
      expect(getCurrentTheme()).toBe("light");
      document.documentElement.classList.add("dark");
      expect(getCurrentTheme()).toBe("dark");
    });
  });

  describe("applyTheme", () => {
    it("toggles the `dark` class on the document element", () => {
      ThemeToggle.applyTheme("dark");
      expect(document.documentElement.classList.contains("dark")).toBe(true);

      ThemeToggle.applyTheme("light");
      expect(document.documentElement.classList.contains("dark")).toBe(false);
    });
  });

  describe("onThemeChange", () => {
    it("invokes registered callbacks with the new theme on applyTheme", () => {
      const callback = vi.fn();
      onThemeChange(callback);

      ThemeToggle.applyTheme("dark");

      expect(callback).toHaveBeenCalledWith("dark");
    });

    it("returns a cleanup function that unsubscribes the callback", () => {
      const callback = vi.fn();
      const unsubscribe = onThemeChange(callback);

      unsubscribe();
      ThemeToggle.applyTheme("dark");

      expect(callback).not.toHaveBeenCalled();
    });
  });
});
