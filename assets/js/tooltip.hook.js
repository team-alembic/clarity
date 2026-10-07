// Hover and focus hints for any element carrying `data-tooltip-*` attributes.
//
// The server renders hint content inline (see `Clarity.Tooltip`), so this hook
// never talks to the server: it owns one shared tooltip element and moves it
// between triggers. With a single element and no async work, two hints can
// never be visible at once and a hint can never outlive its trigger.

const TRIGGER = "[data-tooltip-text], [data-tooltip-title]";
const HINT_ATTRIBUTES = ["data-tooltip-title", "data-tooltip-type", "data-tooltip-text"];

// Hover intent: how long the pointer must rest on a trigger before its hint shows.
export const SHOW_DELAY = 250;
// After a hint hides, entering another trigger within this window shows it at
// once, so sweeping along the tree swaps hints rather than flickering.
export const SKIP_DELAY_WINDOW = 300;

const OFFSET = 8;
const MARGIN = 8;

const clamp = (value, min, max) => Math.max(min, Math.min(value, max));

// Places a tooltip of `size` against `anchor` within `viewport`: below and
// centred by default, flipped above when only that side fits, then shifted to
// stay inside the viewport.
export function computePosition(anchor, size, viewport) {
  const below = anchor.bottom + OFFSET;
  const above = anchor.top - OFFSET - size.height;
  const fitsBelow = below + size.height <= viewport.height - MARGIN;
  const fitsAbove = above >= MARGIN;
  const placement = fitsBelow || !fitsAbove ? "bottom" : "top";

  const top = clamp(
    placement === "bottom" ? below : above,
    MARGIN,
    viewport.height - MARGIN - size.height,
  );
  const left = clamp(
    anchor.left + anchor.width / 2 - size.width / 2,
    MARGIN,
    viewport.width - MARGIN - size.width,
  );

  return { top: Math.round(top), left: Math.round(left), placement };
}

const XLINK = "http://www.w3.org/1999/xlink";

// Graphviz renders each vertex as an <a xlink:href="#vertex-id">. Copies the
// matching hint from `hints` (see `Clarity.Tooltip.hints/1`) onto each link.
export function applyHints(svg, hints) {
  for (const link of svg.querySelectorAll("a")) {
    const href = link.getAttributeNS(XLINK, "href") || link.getAttribute("href") || "";
    const hint = hints[href.replace(/^#/, "")];
    if (!hint) continue;

    link.setAttribute("data-tooltip-title", hint.title);
    link.setAttribute("data-tooltip-type", hint.type);
    if (hint.text) link.setAttribute("data-tooltip-text", hint.text);
  }
}

const findTrigger = (target) =>
  target instanceof Element ? target.closest(TRIGGER) : null;

function textElement(tag, className, text) {
  const el = document.createElement(tag);
  el.className = className;
  el.textContent = text;
  return el;
}

export function createTooltipController(tip) {
  const doc = tip.ownerDocument;
  const win = doc.defaultView;

  let current = null; // trigger whose hint is visible
  let source = null; // how it was shown: "pointer" or "focus"
  let pending = null; // trigger waiting out the show delay
  let timer = null;
  let dismissed = null; // trigger hidden with Escape, ignored until left
  let hiddenAt = -Infinity;

  function render(trigger) {
    const { tooltipTitle, tooltipType, tooltipText } = trigger.dataset;
    const parts = [];
    if (tooltipTitle) parts.push(textElement("div", "clarity-tooltip-title", tooltipTitle));
    if (tooltipType) parts.push(textElement("div", "clarity-tooltip-type", tooltipType));
    if (tooltipText) parts.push(textElement("p", "clarity-tooltip-text", tooltipText));
    tip.replaceChildren(...parts);
  }

  function position(trigger) {
    const size = tip.getBoundingClientRect();
    const { top, left, placement } = computePosition(
      trigger.getBoundingClientRect(),
      size,
      { width: win.innerWidth, height: win.innerHeight },
    );
    tip.style.top = `${top}px`;
    tip.style.left = `${left}px`;
    tip.dataset.placement = placement;
  }

  function describedBy(trigger) {
    return (trigger.getAttribute("aria-describedby") || "").split(/\s+/).filter(Boolean);
  }

  function link(trigger) {
    const ids = describedBy(trigger);
    if (!ids.includes(tip.id)) trigger.setAttribute("aria-describedby", [...ids, tip.id].join(" "));
  }

  function unlink(trigger) {
    const ids = describedBy(trigger).filter((id) => id !== tip.id);
    if (ids.length) trigger.setAttribute("aria-describedby", ids.join(" "));
    else trigger.removeAttribute("aria-describedby");
  }

  function cancelPending() {
    if (timer !== null) win.clearTimeout(timer);
    timer = null;
    pending = null;
  }

  function show(trigger, how) {
    cancelPending();
    if (!trigger.isConnected) return;
    if (current && current !== trigger) unlink(current);

    current = trigger;
    source = how;
    render(trigger);
    tip.hidden = false;
    // Lift into the top layer where supported, so no ancestor can clip it.
    if (tip.showPopover && !tip.matches(":popover-open")) tip.showPopover();
    position(trigger);
    link(trigger);
  }

  function hide() {
    cancelPending();
    if (!current) return;

    unlink(current);
    current = null;
    source = null;
    tip.hidden = true;
    if (tip.hidePopover && tip.matches(":popover-open")) tip.hidePopover();
    hiddenAt = Date.now();
  }

  function schedule(trigger) {
    if (trigger === pending) return;
    cancelPending();

    if (current || Date.now() - hiddenAt < SKIP_DELAY_WINDOW) {
      show(trigger, "pointer");
      return;
    }

    pending = trigger;
    timer = win.setTimeout(() => show(trigger, "pointer"), SHOW_DELAY);
  }

  function onPointerOver(event) {
    if (event.pointerType === "touch") return;

    const trigger = findTrigger(event.target);
    if (trigger !== dismissed) dismissed = null;

    if (!trigger) {
      cancelPending();
      if (source === "pointer") hide();
    } else if (trigger === current) {
      cancelPending();
    } else if (trigger !== dismissed) {
      schedule(trigger);
    }
  }

  function onPointerOut(event) {
    // relatedTarget is null when the pointer leaves the window entirely.
    if (event.relatedTarget) return;
    cancelPending();
    if (source === "pointer") hide();
  }

  function onFocusIn(event) {
    const trigger = findTrigger(event.target);
    if (trigger) {
      dismissed = null;
      show(trigger, "focus");
    }
  }

  function onFocusOut() {
    if (source === "focus") hide();
  }

  function onKeyDown(event) {
    if (event.key === "Escape" && current) {
      dismissed = current;
      hide();
    }
  }

  // LiveView patches can remove a trigger without any pointer event firing, and
  // can rewrite a trigger's hint (e.g. "Copied!" feedback) while it is shown.
  const observer = new win.MutationObserver((records) => {
    if (pending && !pending.isConnected) cancelPending();
    if (!current) return;
    if (!current.isConnected) {
      hide();
    } else if (records.some((r) => r.type === "attributes" && r.target === current)) {
      render(current);
      position(current);
    }
  });
  observer.observe(doc.body, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: HINT_ATTRIBUTES,
  });

  const listeners = [
    [doc, "pointerover", onPointerOver],
    [doc, "pointerout", onPointerOut],
    [doc, "focusin", onFocusIn],
    [doc, "focusout", onFocusOut],
    [doc, "keydown", onKeyDown],
    [doc, "scroll", hide, { capture: true, passive: true }],
    [win, "resize", hide],
    [win, "blur", hide],
    [win, "phx:page-loading-start", hide],
  ];
  for (const [target, type, handler, options] of listeners) {
    target.addEventListener(type, handler, options);
  }

  return {
    destroy() {
      for (const [target, type, handler, options] of listeners) {
        target.removeEventListener(type, handler, options);
      }
      observer.disconnect();
      hide();
    },
  };
}

export default {
  mounted() {
    this.controller = createTooltipController(this.el);
  },
  destroyed() {
    this.controller.destroy();
  },
};
