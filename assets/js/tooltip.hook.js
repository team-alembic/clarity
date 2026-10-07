// Hover and focus hints for any element carrying `data-tooltip-*` attributes.
//
// The server renders hint content inline (see `Clarity.Tooltip`), so this hook
// never talks to the server: it owns one shared tooltip element and moves it
// between triggers. With a single element and no async work, two hints can
// never be visible at once and a hint can never outlive its trigger.

const TRIGGER = "[data-tooltip-text], [data-tooltip-title]";
const HINT_FIELDS = ["title", "type", "icon", "tone", "badges", "text", "facts"];
const HINT_ATTRIBUTES = HINT_FIELDS.map((field) => `data-tooltip-${field}`);
// Hint fields carried as JSON, since they are lists.
const JSON_FIELDS = new Set(["badges", "facts"]);

// Hover intent: how long the pointer must rest on a trigger before its hint shows.
export const SHOW_DELAY = 700;
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

    for (const field of HINT_FIELDS) {
      if (hint[field] == null) continue;
      const value = JSON_FIELDS.has(field) ? JSON.stringify(hint[field]) : hint[field];
      link.setAttribute(`data-tooltip-${field}`, value);
    }
  }
}

const findTrigger = (target) =>
  target instanceof Element ? target.closest(TRIGGER) : null;

const SVG = "http://www.w3.org/2000/svg";

function textElement(tag, className, text) {
  const el = document.createElement(tag);
  el.className = className;
  el.textContent = text;
  return el;
}

// Badges and facts arrive as JSON; anything malformed is dropped rather than
// costing the rest of the hint.
function parseList(json) {
  if (!json) return [];
  try {
    const value = JSON.parse(json);
    return Array.isArray(value) ? value : [];
  } catch {
    return [];
  }
}

// The type label in a pill, led by the vertex type's icon from the page's
// sprite (see `Clarity.IconComponents.vertex_icon_sprite/1`).
function pill(type, icon, tone) {
  const el = textElement("span", "clarity-tooltip-pill", type);
  if (tone) el.dataset.tone = tone;
  if (icon) {
    const svg = document.createElementNS(SVG, "svg");
    svg.setAttribute("class", "clarity-tooltip-icon");
    svg.setAttribute("aria-hidden", "true");
    const use = document.createElementNS(SVG, "use");
    use.setAttribute("href", `#clarity-icon-${icon}`);
    svg.append(use);
    el.prepend(svg);
  }
  return el;
}

function factList(facts) {
  const dl = document.createElement("dl");
  dl.className = "clarity-tooltip-facts";
  for (const fact of facts) {
    if (!Array.isArray(fact) || fact.length !== 2) continue;
    const [label, value] = fact;
    const dd = document.createElement("dd");
    if (Array.isArray(value)) {
      dd.append(...value.map((item) => textElement("span", "clarity-tooltip-chip", String(item))));
    } else {
      dd.textContent = String(value);
    }
    dl.append(textElement("dt", "", String(label)), dd);
  }
  return dl.childElementCount ? dl : null;
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
    const { tooltipTitle, tooltipType, tooltipIcon, tooltipTone, tooltipText } = trigger.dataset;
    const parts = [];
    if (tooltipTitle || tooltipType) {
      // Title on the left, type pill on the right.
      const heading = document.createElement("div");
      heading.className = "clarity-tooltip-heading";
      if (tooltipTitle) heading.append(textElement("div", "clarity-tooltip-title", tooltipTitle));
      if (tooltipType) heading.append(pill(tooltipType, tooltipIcon, tooltipTone));
      parts.push(heading);
    }
    const badges = parseList(trigger.dataset.tooltipBadges);
    if (badges.length) {
      const row = document.createElement("div");
      row.className = "clarity-tooltip-badges";
      row.append(...badges.map((badge) => textElement("span", "clarity-tooltip-badge", String(badge))));
      parts.push(row);
    }
    if (tooltipText) parts.push(textElement("p", "clarity-tooltip-text", tooltipText));
    const facts = factList(parseList(trigger.dataset.tooltipFacts));
    if (facts) parts.push(facts);
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
