// Keeps the current content tab in view when the row of tabs is wider than
// its space and scrolls (see `.content-tabs` in app.css).

// Scrolls `tabs` just far enough to show its current tab in full.
export function revealCurrent(tabs) {
  const current = tabs.querySelector('[aria-current="page"]');
  if (!current) return;

  const start = current.offsetLeft;
  const end = start + current.offsetWidth;

  if (start < tabs.scrollLeft) {
    tabs.scrollLeft = start;
  } else if (end > tabs.scrollLeft + tabs.clientWidth) {
    tabs.scrollLeft = end - tabs.clientWidth;
  }
}

export default {
  mounted() {
    revealCurrent(this.el);
  },
  updated() {
    revealCurrent(this.el);
  },
};
