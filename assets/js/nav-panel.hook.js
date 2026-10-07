// Resizes and collapses the navigation panel, like VS Code's side bar.
//
// The state lives on <html> (a CSS variable for the width and a class for
// collapsed), which LiveView never patches, and is remembered per browser.
// On narrow screens the panel is shown and hidden by the header menu button
// instead; see `.layout-container` in app.css.

const WIDTH_KEY = "clarity:nav-width";
const COLLAPSED_KEY = "clarity:nav-collapsed";
const WIDTH_VAR = "--clarity-nav-width";
const COLLAPSED_CLASS = "clarity-nav-collapsed";
const KEY_STEP = 16;

export const MIN_WIDTH = 192;
const maxWidth = () => Math.max(MIN_WIDTH, Math.round(window.innerWidth * 0.6));

// localStorage can be unavailable (private windows, blocked site data).
function read(key) {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

function write(key, value) {
  try {
    if (value === null) localStorage.removeItem(key);
    else localStorage.setItem(key, value);
  } catch {
    // The panel still works, it just isn't remembered.
  }
}

const root = () => document.documentElement;

function setWidth(width, { save = true } = {}) {
  const clamped = Math.round(Math.min(Math.max(width, MIN_WIDTH), maxWidth()));
  root().style.setProperty(WIDTH_VAR, `${clamped}px`);
  if (save) write(WIDTH_KEY, String(clamped));
}

function setCollapsed(collapsed) {
  root().classList.toggle(COLLAPSED_CLASS, collapsed);
  write(COLLAPSED_KEY, collapsed ? "true" : null);
}

// Restores the saved width and collapsed state; called before LiveView
// connects so the panel doesn't jump.
export function applyNavState() {
  const width = parseInt(read(WIDTH_KEY), 10);
  if (Number.isFinite(width)) setWidth(width, { save: false });
  root().classList.toggle(COLLAPSED_CLASS, read(COLLAPSED_KEY) === "true");
}

const isTyping = (target) =>
  target instanceof Element && target.closest("input, textarea, select, [contenteditable]");

export default {
  mounted() {
    const navWidth = () =>
      document.querySelector(".navigation")?.getBoundingClientRect().width || MIN_WIDTH;

    const onMove = (event) => setWidth(this.startWidth + event.clientX - this.startX);
    const onUp = () => {
      document.removeEventListener("pointermove", onMove);
      document.removeEventListener("pointerup", onUp);
      document.body.classList.remove("select-none", "cursor-col-resize");
    };

    this.onDown = (event) => {
      event.preventDefault();
      this.startX = event.clientX;
      this.startWidth = navWidth();
      document.body.classList.add("select-none", "cursor-col-resize");
      document.addEventListener("pointermove", onMove);
      document.addEventListener("pointerup", onUp);
    };

    this.onKey = (event) => {
      const step = { ArrowLeft: -KEY_STEP, ArrowRight: KEY_STEP }[event.key];
      if (!step) return;
      event.preventDefault();
      setWidth(navWidth() + step);
    };

    this.onReset = () => {
      root().style.removeProperty(WIDTH_VAR);
      write(WIDTH_KEY, null);
    };

    this.onToggle = () => setCollapsed(!root().classList.contains(COLLAPSED_CLASS));

    this.onShortcut = (event) => {
      if (event.key !== "b" || !(event.metaKey || event.ctrlKey) || isTyping(event.target)) return;
      event.preventDefault();
      this.onToggle();
    };

    this.stopDrag = onUp;
    this.el.addEventListener("pointerdown", this.onDown);
    this.el.addEventListener("keydown", this.onKey);
    this.el.addEventListener("dblclick", this.onReset);
    window.addEventListener("clarity:toggle-nav", this.onToggle);
    document.addEventListener("keydown", this.onShortcut);
  },

  destroyed() {
    this.stopDrag();
    this.el.removeEventListener("pointerdown", this.onDown);
    this.el.removeEventListener("keydown", this.onKey);
    this.el.removeEventListener("dblclick", this.onReset);
    window.removeEventListener("clarity:toggle-nav", this.onToggle);
    document.removeEventListener("keydown", this.onShortcut);
  },
};
