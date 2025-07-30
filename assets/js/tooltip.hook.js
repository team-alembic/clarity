const tooltips = new Map();
let mounted = false;

function findTooltipElement(element) {
  if(!element) return;
  if(element === window.document) return;

  if(element.hasAttribute("data-tooltip")) return element;
  return element.closest("[data-tooltip]");
}

function enter(event) {
  const target = findTooltipElement(event.target);
  if (!target) return;

  const tooltipId = target.getAttribute("data-tooltip");
  const tooltip = tooltips.get(tooltipId);
  if (!tooltip) return;

  target.style.anchorName = "--tooltip-anchor";
  tooltip.classList.remove("hidden");
}
function leave(event) {
  const target = findTooltipElement(event.target);
  if (!target) return;

  const tooltipId = target.getAttribute("data-tooltip");
  const tooltip = tooltips.get(tooltipId);
  if (!tooltip) return;

  target.style.anchorName = ""; 
  tooltip.classList.add("hidden");
}

function mount() {
  if (mounted) return;
  mounted = true;

  document.addEventListener("mouseenter", enter, true);
  document.addEventListener("mouseleave", leave, true);
}

export default {
  mounted() {
    tooltips.set(this.el.id, this.el);
    mount();
  },
  destroyed() {
    tooltips.delete(this.el.id);
  },
};