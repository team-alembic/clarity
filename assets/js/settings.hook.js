import {
  applyTheme,
  getThemePreference,
  onSystemThemeChange,
  resolveTheme,
  setThemePreference,
} from "./theme";
import { read, write } from "./storage";

const LINK_LOWERCASE_KEY = "clarity-link-lowercase";

// Whether text links lowercase names too: on unless the viewer turned it off.
export const getLinkLowercase = () => read(LINK_LOWERCASE_KEY) !== "false";

// The settings menu in the header. The viewer's choices live in the browser:
// the hook shows them, applies the theme, and tells the LiveView what it
// renders with, the theme a preference resolves to and whether to link
// lowercase names.
export default {
  mounted() {
    this.showSettings();

    this.el.addEventListener("change", (event) => {
      const input = event.target;
      if (input.name === "theme") this.setTheme(input.value);
      if (input.name === "link_lowercase") this.setLinkLowercase(input.checked);
    });

    // A viewer following the system follows it as it changes.
    this.stopFollowingSystem = onSystemThemeChange(() => {
      if (getThemePreference() === "system") this.showTheme("system");
    });
  },

  destroyed() {
    this.stopFollowingSystem?.();
  },

  showSettings() {
    const preference = getThemePreference();

    for (const radio of this.el.querySelectorAll('input[name="theme"]')) {
      radio.checked = radio.value === preference;
    }

    const linkLowercase = this.el.querySelector('input[name="link_lowercase"]');
    if (linkLowercase) linkLowercase.checked = getLinkLowercase();
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

  setLinkLowercase(enabled) {
    write(LINK_LOWERCASE_KEY, String(enabled));
    this.pushEvent("set-link-lowercase", { enabled });
  },
};
