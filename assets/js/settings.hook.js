import {
  applyTheme,
  getThemePreference,
  onSystemThemeChange,
  resolveTheme,
  setThemePreference,
} from "./theme";
import { read, write } from "./storage";

// How text links names, each option with its default: lowercase names link
// unless turned off, every mention only if turned on.
const LINKING = {
  lowercase: { key: "clarity-link-lowercase", default: true },
  every: { key: "clarity-link-every", default: false },
};

// The viewer's text linking options, as `{lowercase, every}`.
export const getLinking = () =>
  Object.fromEntries(
    Object.entries(LINKING).map(([option, { key, default: enabled }]) => {
      const stored = read(key);
      return [option, stored === null ? enabled : stored === "true"];
    }),
  );

// The gap between the gear and the menu below it, in pixels.
export const MENU_GAP = 4;

// The settings menu in the header. The viewer's choices live in the browser:
// the hook shows them, applies the theme, and tells the LiveView what it
// renders with, the theme a preference resolves to and how text links names.
export default {
  mounted() {
    this.button = this.el.querySelector("button[popovertarget]");
    this.menu = this.el.querySelector("[popover]");
    this.showSettings();

    this.el.addEventListener("change", (event) => {
      const input = event.target;
      if (input.name === "theme") this.setTheme(input.value);
      if ("linking" in input.dataset) this.setLinking(input.name, input.checked);
    });

    // The gear moves with the header's layout, so the menu is placed under it
    // as it opens, and again if the window resizes while it's open.
    this.menu?.addEventListener("beforetoggle", (event) => {
      if (event.newState === "open") this.place();
    });
    this.onResize = () => {
      if (this.menu?.matches(":popover-open")) this.place();
    };
    window.addEventListener("resize", this.onResize);

    // A viewer following the system follows it as it changes.
    this.stopFollowingSystem = onSystemThemeChange(() => {
      if (getThemePreference() === "system") this.showTheme("system");
    });
  },

  destroyed() {
    this.stopFollowingSystem?.();
    window.removeEventListener("resize", this.onResize);
  },

  // Hangs the menu just below the gear, their right edges lined up.
  place() {
    const gear = this.button.getBoundingClientRect();
    this.menu.style.top = `${gear.bottom + MENU_GAP}px`;
    this.menu.style.right = `${window.innerWidth - gear.right}px`;
  },

  showSettings() {
    const preference = getThemePreference();

    for (const radio of this.el.querySelectorAll('input[name="theme"]')) {
      radio.checked = radio.value === preference;
    }

    const linking = getLinking();

    for (const checkbox of this.el.querySelectorAll("input[data-linking]")) {
      checkbox.checked = linking[checkbox.name] ?? false;
    }
  },

  setTheme(preference) {
    setThemePreference(preference);
    this.showTheme(preference);
  },

  showTheme(preference) {
    const theme = resolveTheme(preference);
    applyTheme(theme);
    this.pushEvent("set-theme", { theme });
  },

  setLinking(option, enabled) {
    if (!(option in LINKING)) return;
    write(LINKING[option].key, String(enabled));
    this.pushEvent("set-linking", { [option]: enabled });
  },
};
