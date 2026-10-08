// Rendered diagram SVG, kept so that a diagram shown again (on a tab switch,
// a revisit or a reload) needs no render. Entries live in memory, the most
// recently used kept, and in sessionStorage across page loads where they fit;
// a storage failure only means rendering again.

const MAX_ENTRIES = 50;
const MAX_STORED_LENGTH = 512 * 1024;
const PREFIX = "clarity-svg:";
const memory = new Map();

// A key for the diagram `parts` (element id, theme, source): a 53-bit hash
// (cyrb53) of them, with their total length, so large sources make short keys.
export function cacheKey(...parts) {
  const text = parts.join("\u0000");
  let h1 = 0xdeadbeef;
  let h2 = 0x41c6ce57;
  for (let i = 0; i < text.length; i++) {
    const ch = text.charCodeAt(i);
    h1 = Math.imul(h1 ^ ch, 2654435761);
    h2 = Math.imul(h2 ^ ch, 1597334677);
  }
  h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909);
  h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909);
  const hash = 4294967296 * (2097151 & h2) + (h1 >>> 0);
  return `${hash.toString(36)}:${text.length}`;
}

export function getSvg(key) {
  if (memory.has(key)) {
    const svg = memory.get(key);
    remember(key, svg);
    return svg;
  }
  try {
    const svg = sessionStorage.getItem(PREFIX + key);
    if (svg) {
      remember(key, svg);
      return svg;
    }
  } catch {
    // Storage unavailable: render instead.
  }
  return null;
}

export function putSvg(key, svg) {
  remember(key, svg);
  if (svg.length > MAX_STORED_LENGTH) return;
  try {
    sessionStorage.setItem(PREFIX + key, svg);
  } catch {
    // Full or unavailable: the in-memory copy still serves this page.
  }
}

function remember(key, svg) {
  memory.delete(key);
  memory.set(key, svg);
  if (memory.size > MAX_ENTRIES) memory.delete(memory.keys().next().value);
}
