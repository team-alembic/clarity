import { beforeEach, describe, expect, it, vi } from "vitest";

import { scrollNewPagesToTop } from "../js/scroll.js";

// A window at `path`, whose scrolling the test watches.
function page(path: string) {
  const target = new EventTarget() as EventTarget & { location: URL; scrollTo: ReturnType<typeof vi.fn> };
  target.location = new URL(`http://localhost${path}`);
  target.scrollTo = vi.fn();
  scrollNewPagesToTop(target as unknown as Window);
  return target;
}

function navigate(target: EventTarget, href: string, { patch = true, pop = false } = {}) {
  target.dispatchEvent(new CustomEvent("phx:navigate", { detail: { href, patch, pop } }));
}

describe("scrollNewPagesToTop", () => {
  let target: ReturnType<typeof page>;

  beforeEach(() => {
    target = page("/architect/application:demo");
  });

  it("scrolls to the top on a patch to another page", () => {
    navigate(target, "/architect/ash-resource:demo-projects-ticket");
    expect(target.scrollTo).toHaveBeenCalledWith(0, 0);
  });

  it("keeps the position on a patch that only changes the query", () => {
    navigate(target, "/architect/application:demo?status=warning");
    expect(target.scrollTo).not.toHaveBeenCalled();
  });

  it("leaves going back or forward to LiveView, which restores the position", () => {
    navigate(target, "/architect/ash-resource:demo-projects-ticket", { pop: true });
    expect(target.scrollTo).not.toHaveBeenCalled();
  });

  it("compares with the page shown last", () => {
    navigate(target, "/architect/ash-resource:demo-projects-ticket", { pop: true });
    navigate(target, "/architect/ash-resource:demo-projects-ticket?status=warning");
    expect(target.scrollTo).not.toHaveBeenCalled();
  });
});
