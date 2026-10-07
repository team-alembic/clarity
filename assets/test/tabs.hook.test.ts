import { describe, expect, it } from "vitest";

import { revealCurrent } from "../js/tabs.hook.js";

// A row 300px wide scrolled to `scrollLeft`, holding a tab at `left`..`left + width`
// in the row's own coordinates.
function row(scrollLeft: number, left: number, width: number) {
  const tabs = document.createElement("ul");
  tabs.innerHTML = `<li><a aria-current="page">Current</a></li>`;
  const tab = tabs.querySelector("a")!;
  Object.defineProperty(tabs, "clientWidth", { value: 300 });
  Object.defineProperty(tab, "offsetLeft", { value: left });
  Object.defineProperty(tab, "offsetWidth", { value: width });
  tabs.scrollLeft = scrollLeft;
  return tabs;
}

describe("revealCurrent", () => {
  it("scrolls a current tab cut off on the right fully into view", () => {
    const tabs = row(0, 250, 100);
    revealCurrent(tabs);
    expect(tabs.scrollLeft).toBe(50);
  });

  it("scrolls a current tab cut off on the left fully into view", () => {
    const tabs = row(200, 120, 100);
    revealCurrent(tabs);
    expect(tabs.scrollLeft).toBe(120);
  });

  it("leaves the row alone when the current tab is in view", () => {
    const tabs = row(40, 100, 100);
    revealCurrent(tabs);
    expect(tabs.scrollLeft).toBe(40);
  });

  it("does nothing without a current tab", () => {
    const tabs = row(40, 100, 100);
    tabs.querySelector("a")!.removeAttribute("aria-current");
    revealCurrent(tabs);
    expect(tabs.scrollLeft).toBe(40);
  });
});
