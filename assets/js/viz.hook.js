import * as Viz from "@viz-js/viz";
import { panZoom } from "./pan-zoom";
import { applyHints } from "./tooltip.hook";
import { cacheKey, getSvg, putSvg } from "./svg-cache";

const XLINK = "http://www.w3.org/1999/xlink";

export default {
  async mounted() {
    await this.render();
  },
  async updated() {
    await this.render();
  },
  destroyed() {
    if (this.onResize) window.removeEventListener("resize", this.onResize);
  },

  // Renders the graph, unless it is already showing for this source; a graph
  // rendered before comes from the cache (see svg-cache.js), and Graphviz is
  // only loaded to render one that isn't.
  async render() {
    const graph = this.el.dataset.graph.replace(
      /emit\(/g,
      `emit("${this.el.id}", `
    );
    const key = cacheKey(this.el.id, graph);
    if (key === this.renderedKey) return;

    const svg = await this.svgFor(key, graph);
    this.renderedKey = key;

    // A diagram among an overview's sections (data-pan-zoom="false") keeps
    // its own size, shrinking to fit, so scrolling the page over it scrolls.
    const fixed = this.el.dataset.panZoom === "false";
    if (fixed) {
      svg.style.maxWidth = "100%";
      svg.style.height = "auto";
    } else {
      svg.setAttribute("preserveAspectRatio", "xMidYMid slice");
      svg.setAttribute("width", "100%");
      svg.setAttribute("height", "100%");
    }

    // A click opens the vertex in the graph, or with data-event, sends that.
    const event = this.el.dataset.event || "viz:click";
    [...svg.querySelectorAll("a")].forEach((link) => {
      const href = link.getAttributeNS(XLINK, "href") || link.getAttribute("href");
      if (!href) return;
      const id = href.replace(/^#/, "");
      link.addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        this.pushEvent(event, { id });
      });
    });

    applyHints(svg, JSON.parse(this.el.dataset.tooltips || "{}"));

    if(this.oldSvg) {
      this.oldSvg.remove();
    }
    this.el.appendChild(svg);
    this.oldSvg = svg;

    if (fixed) return;

    const zoom = panZoom(this.el, svg);

    if (this.onResize) window.removeEventListener("resize", this.onResize);
    this.onResize = () => zoom.resize();
    window.addEventListener("resize", this.onResize);
  },

  async svgFor(key, graph) {
    const cached = getSvg(key);
    if (cached) {
      const parsed = new DOMParser().parseFromString(cached, "image/svg+xml");
      return document.importNode(parsed.documentElement, true);
    }

    this.viz ||= await Viz.instance();
    const svg = this.viz.renderSVGElement(graph);
    putSvg(key, new XMLSerializer().serializeToString(svg));
    return svg;
  },
};
