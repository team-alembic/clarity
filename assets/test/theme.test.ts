import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  applyTheme,
  getCurrentTheme,
  getInitialTheme,
  getThemePreference,
  onSystemThemeChange,
  onThemeChange,
  resolveTheme,
  setThemePreference,
} from "../js/theme.js";

// Stub window.matchMedia with a controllable `matches` value. happy-dom's
// built-in implementation does not parse `prefers-color-scheme`, so we drive it
// explicitly per-test.
function stubMatchMedia(matches: boolean) {
  const scheme = { matches, addEventListener: vi.fn(), removeEventListener: vi.fn() };
  vi.stubGlobal("matchMedia", vi.fn().mockReturnValue(scheme));
  return scheme;
}

describe("theme", () => {
  beforeEach(() => {
    localStorage.clear();
    document.documentElement.classList.remove("dark");
    stubMatchMedia(false);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  describe("getThemePreference", () => {
    it("is the stored theme, or the system's when nothing is stored", () => {
      expect(getThemePreference()).toBe("system");

      localStorage.setItem("clarity-theme", "dark");
      expect(getThemePreference()).toBe("dark");
    });

    it("treats an unknown stored value as the system's", () => {
      localStorage.setItem("clarity-theme", "sepia");
      expect(getThemePreference()).toBe("system");
    });
  });

  describe("setThemePreference", () => {
    it("stores light and dark, and forgets the theme to follow the system", () => {
      setThemePreference("light");
      expect(localStorage.getItem("clarity-theme")).toBe("light");

      setThemePreference("system");
      expect(localStorage.getItem("clarity-theme")).toBeNull();
    });
  });

  describe("resolveTheme", () => {
    it("resolves the system preference to the system's theme", () => {
      stubMatchMedia(true);
      expect(resolveTheme("system")).toBe("dark");
      expect(resolveTheme("light")).toBe("light");
    });
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
      applyTheme("dark");
      expect(document.documentElement.classList.contains("dark")).toBe(true);

      applyTheme("light");
      expect(document.documentElement.classList.contains("dark")).toBe(false);
    });
  });

  describe("onThemeChange", () => {
    it("invokes registered callbacks with the new theme on applyTheme", () => {
      const callback = vi.fn();
      onThemeChange(callback);

      applyTheme("dark");

      expect(callback).toHaveBeenCalledWith("dark");
    });

    it("returns a cleanup function that unsubscribes the callback", () => {
      const callback = vi.fn();
      const unsubscribe = onThemeChange(callback);

      unsubscribe();
      applyTheme("dark");

      expect(callback).not.toHaveBeenCalled();
    });
  });

  describe("onSystemThemeChange", () => {
    it("listens for the system's theme changing until cleaned up", () => {
      const scheme = stubMatchMedia(false);
      const callback = vi.fn();

      const stop = onSystemThemeChange(callback);
      expect(scheme.addEventListener).toHaveBeenCalledWith("change", callback);

      stop();
      expect(scheme.removeEventListener).toHaveBeenCalledWith("change", callback);
    });
  });
});
