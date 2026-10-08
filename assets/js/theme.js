import { read, write } from "./storage";

// The viewer's theme preference is "light", "dark", or "system" to follow the
// operating system's. Only light and dark are stored; nothing stored means
// "system".
const THEME_KEY = "clarity-theme";

const darkScheme = () => window.matchMedia("(prefers-color-scheme: dark)");

export const getThemePreference = () => {
  const stored = read(THEME_KEY);
  return stored === "light" || stored === "dark" ? stored : "system";
};

export const setThemePreference = (preference) => {
  write(THEME_KEY, preference === "light" || preference === "dark" ? preference : null);
};

// The theme a preference shows: for "system", the operating system's.
export const resolveTheme = (preference) => {
  if (preference !== "system") return preference;
  return darkScheme().matches ? "dark" : "light";
};

export const getInitialTheme = () => resolveTheme(getThemePreference());

// Get current theme from DOM
export const getCurrentTheme = () => {
  return document.documentElement.classList.contains('dark') ? 'dark' : 'light';
};

// Theme change callback system
const themeChangeCallbacks = new Set();

export const onThemeChange = (callback) => {
  themeChangeCallbacks.add(callback);
  return () => themeChangeCallbacks.delete(callback); // return cleanup function
};

// Shows `theme` ("light" or "dark") with Tailwind's `dark` class, and tells
// the theme change listeners.
export const applyTheme = (theme) => {
  document.documentElement.classList.toggle("dark", theme === "dark");
  themeChangeCallbacks.forEach((callback) => callback(theme));
};

// Calls `callback` when the operating system's theme changes; returns a
// cleanup function.
export const onSystemThemeChange = (callback) => {
  const scheme = darkScheme();
  scheme.addEventListener("change", callback);
  return () => scheme.removeEventListener("change", callback);
};
