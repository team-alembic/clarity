import mermaid from "mermaid";
import svgPanZoom from "svg-pan-zoom";

mermaid.initialize({
  startOnLoad: false,
  securityLevel: "loose",
  flowchart: {
    useMaxWidth: false,
  },
  maxTextSize: 1000000,
});

export default {
  async mounted() {
    await this.render();
  },
  async updated() {
    await this.render();
  },
  async render() {
    const graph = this.el.dataset.graph;

    const { svg: svgRaw } = await mermaid.render(`${this.el.id}_content`, graph);
    this.el.innerHTML = svgRaw;

    const svg = this.el.querySelector("svg");

    svg.setAttribute("preserveAspectRatio", "xMidYMid slice");
    svg.setAttribute("width", "100%");
    svg.setAttribute("height", "100%");
    svg.setAttribute("style", "");
    
    const zoom = svgPanZoom(svg, {
      controlIconsEnabled: true,
      maxZoom: 100,
      contain: true
    });

    window.addEventListener("resize", () => zoom.resize());
  },
};