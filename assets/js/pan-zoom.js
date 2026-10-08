import svgPanZoom from "svg-pan-zoom";

// Lucide-style strokes, drawn in the button's text colour.
const icon = (paths) =>
  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths}</svg>`;

const CONTROLS = [
  ["Zoom in", (zoom) => zoom.zoomIn(), icon('<path d="M12 5v14M5 12h14"/>')],
  ["Zoom out", (zoom) => zoom.zoomOut(), icon('<path d="M5 12h14"/>')],
  [
    "Fit to view",
    (zoom) => zoom.reset(),
    icon('<path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/>'),
  ],
];

// Lets the user pan and zoom a rendered diagram, with a small toolbar of
// zoom controls in the container's corner in place of svg-pan-zoom's own,
// which can't be themed. Replaces the toolbar of an earlier render.
export function panZoom(container, svg) {
  const zoom = svgPanZoom(svg, {
    controlIconsEnabled: false,
    maxZoom: 100,
    contain: true,
  });

  const toolbar = document.createElement("div");
  toolbar.className = "diagram-controls";
  for (const [label, action, svgIcon] of CONTROLS) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "icon-button";
    button.setAttribute("aria-label", label);
    button.dataset.tooltipText = label;
    button.innerHTML = svgIcon;
    button.addEventListener("click", () => action(zoom));
    toolbar.append(button);
  }

  container.querySelector(":scope > .diagram-controls")?.remove();
  container.append(toolbar);

  return zoom;
}
