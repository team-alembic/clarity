// Formats a server-rendered UTC timestamp (`<time datetime="…">`) into the
// browser's local timezone and locale. The element ships with a UTC fallback as
// its text content for the pre-hydration / no-JS case.
export default {
  mounted() {
    this.render();
  },
  updated() {
    this.render();
  },
  render() {
    const iso = this.el.getAttribute("datetime");
    if (!iso) return;

    const date = new Date(iso);
    if (isNaN(date.getTime())) return;

    this.el.textContent = date.toLocaleString(undefined, {
      dateStyle: "long",
      timeStyle: "short",
    });
  },
};
