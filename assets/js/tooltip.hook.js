export let cursorElement;
let placeholderElement;

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

export default {
  mounted() {
    placeholderElement = document.getElementById("tooltip-placeholder");

    if (!cursorElement) {
      cursorElement = document.createElement("div");
      cursorElement.id = "tooltip-cursor";
      document.body.prepend(cursorElement);
      document.addEventListener("mousemove", positionCursorElement, {passive: true});
      document.addEventListener("mouseenter", this.enter.bind(this), {capture: true, passive: true});
    }
  },
  enter(event) {
    const target = findTooltipTriggerElement(event.target);
    if (!target) return;

    const tooltipId = target.getAttribute("data-tooltip");
    const tooltip = document.getElementById(tooltipId);

    if (tooltip) {
      tooltip.classList.remove("hidden");
      target.addEventListener("mouseleave", () => {
        tooltip.classList.add("hidden");
      }, {once: true, passive: true});
    } else {
      let shownTooltip = null;
      let resolved = false;

      // Delay showing placeholder to avoid flash for elements without tooltips
      const placeholderTimeout = setTimeout(() => {
        if (!resolved) {
          shownTooltip = placeholderElement;
          shownTooltip.classList.remove("hidden");
        }
      }, 150);

      target.addEventListener("mouseleave", () => {
        clearTimeout(placeholderTimeout);
        if (shownTooltip) {
          shownTooltip.classList.add("hidden");
        }
      }, {once: true, passive: true});

      this.pushEventTo(this.el, "load_tooltip", {vertex_id: tooltipId}, (response) => {
        resolved = true;
        clearTimeout(placeholderTimeout);
        if (shownTooltip) {
          shownTooltip.classList.add("hidden");
        }
        if(response.added) {
          shownTooltip = document.getElementById(tooltipId);
          shownTooltip.classList.remove("hidden");
        }
      })
    }
  }
};