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
// After a press, hints wait until the pointer has moved this far (in px), so
// clicking around doesn't pop them up between clicks.
export const PRESS_QUIET_DISTANCE = 16;

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
// matching hint from `hints` (see `Clarity.Tooltip.hints/1`) onto each link,
// and drops the tooltips the browser would show of its own.
export function applyHints(svg, hints) {
  // Graphviz titles every node, edge and the graph itself, and the browser
  // shows those as its own tooltips, beside the hint: an empty box for a
  // node's blank title.
  for (const title of svg.querySelectorAll("title")) title.remove();

  for (const link of svg.querySelectorAll("a")) {
    link.removeAttributeNS(XLINK, "title");

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
  let dismissed = null; // trigger hidden with Escape or a press, ignored until left
  let hiddenAt = -Infinity;
  let pressedAt = null; // where the last press was, until the pointer moves away
  let pressing = false; // between pointerdown and pointerup

  // A badge is its text, or its text and the kind that colours it.
  function badgeElement(badge) {
    const [text, kind] = Array.isArray(badge) ? badge : [badge];
    const element = textElement("span", "clarity-tooltip-badge", String(text));
    if (kind) element.dataset.kind = String(kind);
    return element;
  }

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
      row.append(...badges.map(badgeElement));
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

    // A container such as the navigation tree, where the pointer passes over
    // many triggers on its way somewhere, can ask for a longer delay. Its
    // hints then always wait, rather than swapping as the pointer moves on.
    const ownDelay = Number(trigger.closest("[data-tooltip-delay]")?.dataset.tooltipDelay);

    if (ownDelay) {
      if (source === "pointer") hide();
    } else if (current || Date.now() - hiddenAt < SKIP_DELAY_WINDOW) {
      show(trigger, "pointer");
      return;
    }

    pending = trigger;
    timer = win.setTimeout(() => show(trigger, "pointer"), ownDelay || SHOW_DELAY);
  }

  // Hints follow Radix UI's tooltip: the delay starts when the pointer moves
  // over a trigger, not when a trigger appears under a still pointer (as
  // after a LiveView patch), and a press hides the hint until the pointer
  // leaves that trigger.
  function onPointerOver(event) {
    if (event.pointerType === "touch") return;

    const trigger = findTrigger(event.target);
    if (trigger !== dismissed) dismissed = null;

    if (!trigger) {
      cancelPending();
      if (source === "pointer") hide();
    } else if (trigger === current) {
      cancelPending();
    }
  }

  function onPointerMove(event) {
    if (event.pointerType === "touch") return;

    if (pressedAt) {
      const moved = Math.hypot(event.clientX - pressedAt.x, event.clientY - pressedAt.y);
      if (moved < PRESS_QUIET_DISTANCE) return;
      pressedAt = null;
    }

    const trigger = findTrigger(event.target);
    if (trigger && trigger !== current && trigger !== dismissed) schedule(trigger);
  }

  function onPointerDown(event) {
    pressing = true;
    pressedAt = { x: event.clientX, y: event.clientY };
    dismissed = findTrigger(event.target);
    hide();
    // A press isn't sweeping between hints, so the next one waits in full.
    hiddenAt = -Infinity;
  }

  function onPointerUp() {
    pressing = false;
  }

  function onPointerOut(event) {
    // relatedTarget is null when the pointer leaves the window entirely.
    if (event.relatedTarget) return;
    cancelPending();
    if (source === "pointer") hide();
  }

  function onFocusIn(event) {
    // Focus a press gives, rather than the keyboard, shows nothing.
    if (pressing) return;

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
    } else {
      // Typing or a shortcut restarts the wait; the pointer must move again.
      cancelPending();
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
    [doc, "pointermove", onPointerMove, { passive: true }],
    [doc, "pointerdown", onPointerDown, { capture: true }],
    [doc, "pointerup", onPointerUp, { capture: true }],
    [doc, "pointercancel", onPointerUp, { capture: true }],
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
