import mermaid from "mermaid";
import svgPanZoom from "svg-pan-zoom";
import { onThemeChange, getInitialTheme, getCurrentTheme } from "./theme.hook";
import { cacheKey, getSvg, putSvg } from "./svg-cache";

const getMermaidTheme = (theme) => {
  return theme === 'dark' ? 'dark' : 'default';
};

const initialize = (theme) =>
  mermaid.initialize({
    startOnLoad: false,
    securityLevel: "loose",
    theme,
    flowchart: {
      useMaxWidth: false,
    },
    maxTextSize: 1000000,
  });

// Initialize with current theme
initialize(getMermaidTheme(getInitialTheme()));

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
      initialize(mermaidTheme);
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

    const zoom = svgPanZoom(svg, {
      controlIconsEnabled: true,
      maxZoom: 100,
      contain: true
    });

    if (this.onResize) window.removeEventListener("resize", this.onResize);
    this.onResize = () => zoom.resize();
    window.addEventListener("resize", this.onResize);
  },
};
