import { beforeEach, describe, expect, it, vi } from "vitest";

import { scrollNewPagesToTop } from "../js/scroll.js";

// A window at `path`, with its content beside the navigation, whose
// scrolling the test watches.
function page(path: string) {
  const content = { scrollTo: vi.fn() };

  const target = new EventTarget() as EventTarget & {
    location: URL;
    scrollTo: ReturnType<typeof vi.fn>;
    document: { querySelectorAll: (selector: string) => (typeof content)[] };
    content: typeof content;
  };

  target.location = new URL(`http://localhost${path}`);
  target.scrollTo = vi.fn();
  target.content = content;
  target.document = {
    querySelectorAll: (selector) => (selector === ".layout-container > .content" ? [content] : []),
  };
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

  it("scrolls the content beside the navigation to its top too, as it scrolls on its own", () => {
    navigate(target, "/architect/ash-resource:demo-projects-ticket");
    expect(target.content.scrollTo).toHaveBeenCalledWith(0, 0);
  });

  it("keeps the position on a patch that only changes the query", () => {
    navigate(target, "/architect/application:demo?status=warning");
    expect(target.scrollTo).not.toHaveBeenCalled();
    expect(target.content.scrollTo).not.toHaveBeenCalled();
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
