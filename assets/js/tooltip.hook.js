const tooltips = new Map();
export let cursorElement;

let mounted = false;

function positionCursorElement(event) {
  cursorElement.style.top = event.clientY + "px";
  cursorElement.style.left = event.clientX + "px";
}

function findTooltipTriggerElement(element) {
  if(!element) return;
  if(element === window.document) return;

  if(element.hasAttribute("data-tooltip")) return element;
  return element.closest("[data-tooltip]");
}
function findTooltipElement(trigger) {
  const tooltipId = trigger.getAttribute("data-tooltip");
  return tooltips.get(tooltipId);
}

function enter(event) {
  const target = findTooltipTriggerElement(event.target);
  if (!target) return;
  const tooltip = findTooltipElement(target);
  if (!tooltip) return;

  tooltip.classList.remove("hidden");

  target.addEventListener("mouseleave", () => {
    tooltip.classList.add("hidden");
  }, {once: true, passive: true});
}

function mount() {
  if (mounted) return;
  mounted = true;

  cursorElement = document.createElement("div");
  cursorElement.id = "tooltip-cursor";
  document.body.prepend(cursorElement);

  document.addEventListener("mousemove", positionCursorElement, {passive: true});
  document.addEventListener("mouseenter", enter, {capture: true, passive: true});
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