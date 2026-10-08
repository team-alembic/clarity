import { describe, expect, it } from "vitest";

import { reveal } from "../js/tree.hook.js";

// A navigation 500px tall, with a 32px sticky heading, scrolled to `scrollTop`,
// holding a 20px row at `rowTop` in the viewport.
function navigation(scrollTop: number, rowTop: number) {
  const scroller = document.createElement("nav");
  scroller.innerHTML = `<div class="nav-heading"></div><a aria-current="page">Row</a>`;
  const heading = scroller.querySelector(".nav-heading")!;
  const row = scroller.querySelector("a")!;
  Object.defineProperty(heading, "offsetHeight", { value: 32 });
  scroller.getBoundingClientRect = () => ({ top: 0, bottom: 500, height: 500 }) as DOMRect;
  row.getBoundingClientRect = () => ({ top: rowTop, bottom: rowTop + 20, height: 20 }) as DOMRect;
  scroller.scrollTop = scrollTop;
  return { scroller, row };
}

describe("reveal", () => {
  it("leaves the navigation alone when the row is in view", () => {
    const { scroller, row } = navigation(100, 200);
    reveal(scroller, row);
    expect(scroller.scrollTop).toBe(100);
  });

  it("scrolls a row below the view up into the middle", () => {
    const { scroller, row } = navigation(0, 1200);
    reveal(scroller, row);
    // The space below the heading is 468px; the row's top lands 224px into it.
    expect(scroller.scrollTop).toBe(1200 - 32 - 224);
  });

  it("scrolls a row hidden under the sticky heading down into the middle", () => {
    const { scroller, row } = navigation(1000, 10);
    reveal(scroller, row);
    expect(scroller.scrollTop).toBe(1000 + 10 - 32 - 224);
  });
});
