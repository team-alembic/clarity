import * as Viz from "@viz-js/viz";
import svgPanZoom from "svg-pan-zoom";

export default {
  async mounted() {
    this.width = this.el.clientWidth;
    this.height = this.el.clientHeight;
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

    // TODO: Can we remove this and use flexbox somehow?
    svg.setAttribute("preserveAspectRatio", "xMidYMid slice");
    svg.setAttribute("width", this.width);
    svg.setAttribute("height", this.height);

    [...svg.querySelectorAll("a")].forEach((link) => {
      const id = link.getAttribute("xlink:href").replace(/^#/, "");
      link.addEventListener("click", (event) => {
        event.preventDefault();
        event.stopPropagation();
        this.pushEvent("viz:click", { id });
      });
    });

    if(this.oldSvg) {
      this.oldSvg.remove();
    }
    this.el.appendChild(svg);
    this.oldSvg = svg;
    
    svgPanZoom(svg, {
      controlIconsEnabled: true,
      maxZoom: 100,
      contain: true
    });
  },
};