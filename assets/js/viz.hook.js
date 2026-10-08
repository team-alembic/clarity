import * as Viz from "@viz-js/viz";
import svgPanZoom from "svg-pan-zoom";
import { applyHints } from "./tooltip.hook";
import { cacheKey, getSvg, putSvg } from "./svg-cache";

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

    svg.setAttribute("preserveAspectRatio", "xMidYMid slice");
    svg.setAttribute("width", "100%");
    svg.setAttribute("height", "100%");

    [...svg.querySelectorAll('a[*|href]')].forEach((link) => {
      const id = link.getAttributeNS('http://www.w3.org/1999/xlink', 'href').replace(/^#/, "");
      link.addEventListener("click", (event) => {
        event.preventDefault();
        event.stopPropagation();
        this.pushEvent("viz:click", { id });
      });
    });

    applyHints(svg, JSON.parse(this.el.dataset.tooltips || "{}"));

    if(this.oldSvg) {
      this.oldSvg.remove();
    }
    this.el.appendChild(svg);
    this.oldSvg = svg;

    const zoom = svgPanZoom(svg, {
      controlIconsEnabled: true,
      maxZoom: 100,
      contain: true
    });

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
