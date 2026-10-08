import { beforeEach, describe, expect, it, vi } from "vitest";

// A fresh copy of the module, so its in-memory entries start empty.
async function freshCache() {
  vi.resetModules();
  return await import("../js/svg-cache.js");
}

// sessionStorage that fails, as when it is full or disabled.
function failingStorage() {
  const fail = () => {
    throw new Error("QuotaExceededError");
  };
  vi.stubGlobal("sessionStorage", { getItem: fail, setItem: fail });
}

beforeEach(() => {
  vi.unstubAllGlobals();
  sessionStorage.clear();
});

describe("cacheKey", () => {
  it("is the same for the same parts and differs for different ones", async () => {
    const { cacheKey } = await freshCache();

    expect(cacheKey("a", "dark", "graph {}")).toBe(cacheKey("a", "dark", "graph {}"));
    expect(cacheKey("a", "dark", "graph {}")).not.toBe(cacheKey("a", "light", "graph {}"));
  });

  it("tells apart parts that only differ in where they split", async () => {
    const { cacheKey } = await freshCache();

    expect(cacheKey("ab", "c")).not.toBe(cacheKey("a", "bc"));
  });
});

describe("getSvg and putSvg", () => {
  it("returns nothing for a diagram never rendered", async () => {
    const { getSvg } = await freshCache();

    expect(getSvg("missing")).toBeNull();
  });

  it("returns a rendered diagram, from memory and across page loads", async () => {
    const first = await freshCache();
    first.putSvg("k", "<svg>one</svg>");
    expect(first.getSvg("k")).toBe("<svg>one</svg>");

    const afterReload = await freshCache();
    expect(afterReload.getSvg("k")).toBe("<svg>one</svg>");
  });

  it("keeps a very large diagram in memory only", async () => {
    const { getSvg, putSvg } = await freshCache();
    const large = `<svg>${"x".repeat(600 * 1024)}</svg>`;

    putSvg("large", large);

    expect(getSvg("large")).toBe(large);
    expect(sessionStorage.length).toBe(0);
  });

  it("still serves the page from memory when storage fails", async () => {
    const { getSvg, putSvg } = await freshCache();
    failingStorage();

    putSvg("k", "<svg>two</svg>");

    expect(getSvg("k")).toBe("<svg>two</svg>");
  });

  it("keeps the fifty most recently used diagrams in memory", async () => {
    const { getSvg, putSvg } = await freshCache();
    failingStorage();

    for (let i = 0; i <= 50; i++) putSvg(`k${i}`, `<svg>${i}</svg>`);

    expect(getSvg("k0")).toBeNull();
    expect(getSvg("k50")).toBe("<svg>50</svg>");
  });
});
