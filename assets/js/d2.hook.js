import { D2 } from "@terrastruct/d2";
import svgPanZoom from "svg-pan-zoom";

const d2 = new D2();

const themeIdFor = (theme) => (theme === "dark" ? 200 : 0);

export default {
  async mounted() {
    await this.render();
  },
  async updated() {
    await this.render();
  },
  async render() {
    const source = this.el.dataset.graph;
    const layout = this.el.dataset.layout === "elk" ? "elk" : "dagre";
    const theme = this.el.dataset.theme === "dark" ? "dark" : "light";

    let svgString;
    try {
      const compiled = await d2.compile(source, {
        layout,
        themeID: themeIdFor(theme),
      });
      svgString = await d2.render(compiled.diagram, {
        ...compiled.renderOptions,
        center: true,
        noXMLTag: true,
        forceAppendix: true,
      });
    } catch (err) {
      console.error("D2 render error:", err);
      this.el.innerHTML = `<div class="text-red-600 dark:text-red-400 font-mono text-sm whitespace-pre-wrap p-4">D2 render error:\n${(err && err.message) || err}</div>`;
      return;
    }

    if (this.oldSvg) {
      this.oldSvg.remove();
    }

    const wrapper = document.createElement("div");
    wrapper.innerHTML = svgString;
    const svg = wrapper.querySelector("svg");
    if (!svg) {
      this.el.innerHTML = `<div class="text-red-600 dark:text-red-400 font-mono text-sm p-4">D2 produced no SVG.</div>`;
      return;
    }

    svg.removeAttribute("width");
    svg.removeAttribute("height");
    svg.setAttribute("preserveAspectRatio", "xMidYMid meet");
    svg.setAttribute("width", "100%");
    svg.setAttribute("height", "100%");

    [...svg.querySelectorAll("a")].forEach((link) => {
      const href = link.getAttribute("href") || link.getAttribute("xlink:href") || "";
      const match = href.match(/^vertex:\/\/(.+)$/);
      if (!match) return;
      const id = match[1];
      link.removeAttribute("target");
      link.addEventListener("click", (event) => {
        event.preventDefault();
        event.stopPropagation();
        this.pushEvent("viz:click", { id });
      });
      link.setAttribute("data-tooltip", `tooltip-${id}`);
    });

    this.el.appendChild(svg);
    this.oldSvg = svg;

    const zoom = svgPanZoom(svg, {
      controlIconsEnabled: true,
      maxZoom: 100,
      contain: true,
    });

    window.addEventListener("resize", () => zoom.resize());
  },
};
