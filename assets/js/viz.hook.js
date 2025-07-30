import * as Viz from "@viz-js/viz";
import svgPanZoom from "svg-pan-zoom";

export default {
  async mounted() {
    this.viz = await Viz.instance();
    await this.render();
  },
  async updated() {
    await this.render();
  },
  async render() {
    const graph = this.el.dataset.graph.replace(
      /emit\(/g,
      `emit("${this.el.id}", `
    );

    const svg = this.viz.renderSVGElement(graph);

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
      link.setAttribute("data-tooltip", `tooltip-${id}`);
    });

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

    window.addEventListener("resize", () => zoom.resize());
  },
};