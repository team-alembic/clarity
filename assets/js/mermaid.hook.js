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
    this.width = this.el.clientWidth;
    this.height = this.el.clientHeight;
    await this.render();
  },
  async updated() {
    await this.render();
  },
  async render() {
    const graph = this.el.dataset.graph;

    const { svg } = await mermaid.render(`${this.el.id}_content`, graph);
    this.el.innerHTML = svg;

    const svgElem = this.el.querySelector("svg");

    // TODO: Can we remove this and use flexbox somehow?
    svgElem.setAttribute("width", this.width);
    svgElem.setAttribute("height", this.height);
    svgElem.setAttribute("style", "");

    svgPanZoom(svgElem, {
      controlIconsEnabled: true,
      maxZoom: 100,
    });
  },
};