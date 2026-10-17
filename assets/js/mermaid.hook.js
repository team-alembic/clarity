import { panZoom } from "./pan-zoom";
import { onThemeChange, getCurrentTheme } from "./theme";
import { cacheKey, getSvg, putSvg } from "./svg-cache";

const getMermaidTheme = (theme) => {
  return theme === 'dark' ? 'dark' : 'default';
};

// Mermaid is most of Clarity's JS, so it loads, in chunks of its own, when
// the first diagram renders, and each kind of diagram loads as it's drawn.
let loaded;
const loadMermaid = () =>
  (loaded ||= import("mermaid").then(({ default: mermaid }) => mermaid));

const initialize = (mermaid, theme) =>
  mermaid.initialize({
    startOnLoad: false,
    securityLevel: "loose",
    theme,
    flowchart: {
      useMaxWidth: false,
    },
    maxTextSize: 1000000,
  });

export default {
  async mounted() {
    this.unsubscribeThemeChange = onThemeChange(() => {
      this.render();
    });

    await this.render();
  },

  destroyed() {
    if (this.unsubscribeThemeChange) {
      this.unsubscribeThemeChange();
    }
    if (this.onResize) window.removeEventListener("resize", this.onResize);
  },

  async updated() {
    await this.render();
  },

  // Renders the diagram, unless it is already showing for this source and
  // theme; a diagram rendered before comes from the cache (see svg-cache.js).
  async render() {
    const mermaidTheme = getMermaidTheme(getCurrentTheme());
    const graph = this.el.dataset.graph;
    const key = cacheKey(this.el.id, mermaidTheme, graph);
    if (key === this.renderedKey) return;

    let svgRaw = getSvg(key);
    if (!svgRaw) {
      const mermaid = await loadMermaid();
      initialize(mermaid, mermaidTheme);
      ({ svg: svgRaw } = await mermaid.render(`${this.el.id}_content`, graph));
      putSvg(key, svgRaw);
    }

    this.renderedKey = key;
    this.el.innerHTML = svgRaw;

    const svg = this.el.querySelector("svg");

    svg.setAttribute("width", "100%");
    svg.setAttribute("height", "100%");
    svg.setAttribute("style", "");

    // A small diagram among others (data-pan-zoom="false") just fits its box,
    // so scrolling the page over it scrolls rather than zooms.
    if (this.el.dataset.panZoom === "false") {
      svg.setAttribute("preserveAspectRatio", "xMidYMid meet");
      return;
    }

    svg.setAttribute("preserveAspectRatio", "xMidYMid slice");

    const zoom = panZoom(this.el, svg);

    if (this.onResize) window.removeEventListener("resize", this.onResize);
    this.onResize = () => zoom.resize();
    window.addEventListener("resize", this.onResize);
  },
};
