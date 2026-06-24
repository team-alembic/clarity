import mermaid from "mermaid";
import svgPanZoom from "svg-pan-zoom";
import { onThemeChange, getInitialTheme, getCurrentTheme } from "./theme.hook";

const getMermaidTheme = (theme) => {
  return theme === 'dark' ? 'dark' : 'default';
};

// Initialize with current theme
mermaid.initialize({
  startOnLoad: false,
  securityLevel: "loose",
  theme: getMermaidTheme(getInitialTheme()),
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
  },
  
  async updated() {
    await this.render();
  },
  
  async render() {
    const currentTheme = getCurrentTheme(); // This gets current theme from DOM
    const mermaidTheme = getMermaidTheme(currentTheme);
    
    mermaid.initialize({
      startOnLoad: false,
      securityLevel: "loose",
      theme: mermaidTheme,
      flowchart: {
        useMaxWidth: false,
      },
      maxTextSize: 1000000,
    });

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