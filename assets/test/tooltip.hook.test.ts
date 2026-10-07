import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  applyHints,
  computePosition,
  createTooltipController,
  SHOW_DELAY,
  SKIP_DELAY_WINDOW,
} from "../js/tooltip.hook.js";

const rect = (left: number, top: number, width: number, height: number) => ({
  left,
  top,
  width,
  height,
  right: left + width,
  bottom: top + height,
  x: left,
  y: top,
  toJSON: () => ({}),
});

describe("computePosition", () => {
  const viewport = { width: 1000, height: 800 };
  const size = { width: 80, height: 40 };

  it("places the tooltip below the anchor, centred on it", () => {
    expect(computePosition(rect(200, 100, 100, 20), size, viewport)).toEqual({
      top: 128,
      left: 210,
      placement: "bottom",
    });
  });

  it("flips above the anchor when there is no room below", () => {
    expect(computePosition(rect(200, 760, 100, 20), size, viewport)).toEqual({
      top: 712,
      left: 210,
      placement: "top",
    });
  });

  it("shifts back inside the left edge", () => {
    expect(computePosition(rect(0, 100, 20, 20), size, viewport).left).toBe(8);
  });

  it("shifts back inside the right edge", () => {
    expect(computePosition(rect(990, 100, 10, 20), size, viewport).left).toBe(912);
  });
});

describe("tooltip controller", () => {
  let tip: HTMLElement;
  let vertex: HTMLAnchorElement;
  let vertexChild: HTMLSpanElement;
  let label: HTMLButtonElement;
  let plain: HTMLDivElement;
  let controller: { destroy(): void };

  const hover = (el: Element, pointerType = "mouse") =>
    el.dispatchEvent(new PointerEvent("pointerover", { bubbles: true, pointerType }));
  const shown = () => !tip.hidden;
  const flushObservers = () => vi.advanceTimersByTimeAsync(0);

  beforeEach(() => {
    vi.useFakeTimers();
    document.body.innerHTML = `
      <div id="clarity-tooltip" role="tooltip" hidden></div>
      <a id="vertex" href="#"
         data-tooltip-title="Docket.Accounts.User"
         data-tooltip-type="Ash Resource"
         data-tooltip-text="A staff login."><span id="vertex-child">Docket.Accounts.User</span></a>
      <button id="label" data-tooltip-text="Copy to clipboard">⧉</button>
      <div id="plain">no hint here</div>
    `;
    tip = document.getElementById("clarity-tooltip")!;
    vertex = document.getElementById("vertex") as HTMLAnchorElement;
    vertexChild = document.getElementById("vertex-child") as HTMLSpanElement;
    label = document.getElementById("label") as HTMLButtonElement;
    plain = document.getElementById("plain") as HTMLDivElement;
    controller = createTooltipController(tip);
  });

  afterEach(() => {
    controller.destroy();
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  describe("hover", () => {
    it("shows a vertex hint only once the hover delay has passed", () => {
      hover(vertex);
      vi.advanceTimersByTime(SHOW_DELAY - 1);
      expect(shown()).toBe(false);

      vi.advanceTimersByTime(1);
      expect(shown()).toBe(true);
      expect(tip.textContent).toContain("Docket.Accounts.User");
      expect(tip.textContent).toContain("Ash Resource");
      expect(tip.textContent).toContain("A staff login.");
    });

    it("shows just the text for a label hint", () => {
      hover(label);
      vi.advanceTimersByTime(SHOW_DELAY);

      expect(tip.textContent).toBe("Copy to clipboard");
    });

    it("renders hint content as text, never as HTML", () => {
      label.dataset.tooltipText = "<img src=x onerror=alert(1)>";
      hover(label);
      vi.advanceTimersByTime(SHOW_DELAY);

      expect(tip.querySelector("img")).toBeNull();
      expect(tip.textContent).toBe("<img src=x onerror=alert(1)>");
    });

    it("never shows a hint when the pointer leaves before the delay", () => {
      hover(vertex);
      vi.advanceTimersByTime(SHOW_DELAY / 2);
      hover(plain);
      vi.advanceTimersByTime(SHOW_DELAY * 4);

      expect(shown()).toBe(false);
    });

    it("hides immediately when the pointer leaves a shown trigger", () => {
      hover(vertex);
      vi.advanceTimersByTime(SHOW_DELAY);
      hover(plain);

      expect(shown()).toBe(false);
    });

    it("keeps the hint while the pointer moves over the trigger's children", () => {
      hover(vertex);
      vi.advanceTimersByTime(SHOW_DELAY);
      hover(vertexChild);

      expect(shown()).toBe(true);
      expect(tip.textContent).toContain("Docket.Accounts.User");
    });

    it("swaps straight to the next trigger without waiting again", () => {
      hover(vertex);
      vi.advanceTimersByTime(SHOW_DELAY);
      hover(label);

      expect(tip.textContent).toBe("Copy to clipboard");
    });

    it("skips the delay when re-entering a trigger soon after a hint hid", () => {
      hover(vertex);
      vi.advanceTimersByTime(SHOW_DELAY);
      hover(plain);
      vi.advanceTimersByTime(SKIP_DELAY_WINDOW - 1);
      hover(label);

      expect(shown()).toBe(true);
    });

    it("waits for the delay again once the skip window has passed", () => {
      hover(vertex);
      vi.advanceTimersByTime(SHOW_DELAY);
      hover(plain);
      vi.advanceTimersByTime(SKIP_DELAY_WINDOW);
      hover(label);

      expect(shown()).toBe(false);
    });

    it("ignores touch pointers", () => {
      hover(vertex, "touch");
      vi.advanceTimersByTime(SHOW_DELAY * 4);

      expect(shown()).toBe(false);
    });

    it("hides when the pointer leaves the window", () => {
      hover(vertex);
      vi.advanceTimersByTime(SHOW_DELAY);
      document.dispatchEvent(new PointerEvent("pointerout", { bubbles: true, relatedTarget: null }));

      expect(shown()).toBe(false);
    });
  });

  describe("keyboard", () => {
    it("shows immediately on focus and hides on blur", () => {
      vertex.dispatchEvent(new FocusEvent("focusin", { bubbles: true }));
      expect(shown()).toBe(true);

      vertex.dispatchEvent(new FocusEvent("focusout", { bubbles: true }));
      expect(shown()).toBe(false);
    });

    it("keeps a focus hint when the pointer wanders off", () => {
      vertex.dispatchEvent(new FocusEvent("focusin", { bubbles: true }));
      hover(plain);

      expect(shown()).toBe(true);
    });

    it("Escape dismisses the hint until the pointer moves to another trigger", () => {
      hover(vertex);
      vi.advanceTimersByTime(SHOW_DELAY);
      document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
      expect(shown()).toBe(false);

      hover(vertexChild);
      vi.advanceTimersByTime(SHOW_DELAY * 4);
      expect(shown()).toBe(false);

      hover(label);
      vi.advanceTimersByTime(SHOW_DELAY);
      expect(shown()).toBe(true);
    });
  });

  describe("page changes", () => {
    it("hides when the trigger is removed from the page", async () => {
      hover(vertex);
      vi.advanceTimersByTime(SHOW_DELAY);
      vertex.remove();
      await flushObservers();

      expect(shown()).toBe(false);
    });

    it("never shows a pending hint whose trigger was removed", async () => {
      hover(vertex);
      vertex.remove();
      await flushObservers();
      vi.advanceTimersByTime(SHOW_DELAY);

      expect(shown()).toBe(false);
    });

    it("updates the shown hint when the trigger's text changes", async () => {
      hover(label);
      vi.advanceTimersByTime(SHOW_DELAY);
      label.dataset.tooltipText = "Copied!";
      await flushObservers();

      expect(tip.textContent).toBe("Copied!");
    });

    it("hides on scroll", () => {
      hover(vertex);
      vi.advanceTimersByTime(SHOW_DELAY);
      document.dispatchEvent(new Event("scroll"));

      expect(shown()).toBe(false);
    });

    it("hides when LiveView starts navigating", () => {
      hover(vertex);
      vi.advanceTimersByTime(SHOW_DELAY);
      window.dispatchEvent(new CustomEvent("phx:page-loading-start"));

      expect(shown()).toBe(false);
    });
  });

  describe("accessibility", () => {
    it("describes the trigger while shown, keeping existing descriptions", () => {
      vertex.setAttribute("aria-describedby", "other");
      hover(vertex);
      vi.advanceTimersByTime(SHOW_DELAY);
      expect(vertex.getAttribute("aria-describedby")).toBe("other clarity-tooltip");

      hover(plain);
      expect(vertex.getAttribute("aria-describedby")).toBe("other");
    });

    it("removes aria-describedby it added once hidden", () => {
      hover(label);
      vi.advanceTimersByTime(SHOW_DELAY);
      hover(plain);

      expect(label.hasAttribute("aria-describedby")).toBe(false);
    });
  });

  describe("positioning", () => {
    it("places the tooltip against the trigger, not the pointer", () => {
      vi.spyOn(vertex, "getBoundingClientRect").mockReturnValue(rect(200, 100, 100, 20));
      vi.spyOn(tip, "getBoundingClientRect").mockReturnValue(rect(0, 0, 80, 40));

      hover(vertex);
      vi.advanceTimersByTime(SHOW_DELAY);

      expect(tip.style.top).toBe("128px");
      expect(tip.style.left).toBe("210px");
    });
  });

  describe("lifecycle", () => {
    it("stops responding once destroyed", () => {
      controller.destroy();
      hover(vertex);
      vi.advanceTimersByTime(SHOW_DELAY * 4);

      expect(shown()).toBe(false);
    });
  });
});

describe("applyHints", () => {
  it("gives graph nodes their hint by the vertex id in their link", () => {
    document.body.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
        <a id="with-hint" xlink:href="#application:demo"><text>demo</text></a>
        <a id="without-hint" xlink:href="#root"><text>Root</text></a>
      </svg>
    `;

    applyHints(document.querySelector("svg")!, {
      "application:demo": { title: "demo", type: "Application", text: "Demo app." },
    });

    const withHint = document.getElementById("with-hint")!;
    expect(withHint.getAttribute("data-tooltip-title")).toBe("demo");
    expect(withHint.getAttribute("data-tooltip-type")).toBe("Application");
    expect(withHint.getAttribute("data-tooltip-text")).toBe("Demo app.");
    expect(document.getElementById("without-hint")!.hasAttribute("data-tooltip-title")).toBe(false);
  });
});
