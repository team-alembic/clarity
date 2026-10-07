# Design: Tooltip Overhaul

Status: Implemented · 2026-10-07

## Problem

Measured against a real app (docket, `clarity 0.6.0`) with Playwright:

| # | Issue | Evidence |
|---|---|---|
| 1 | Positioning relied solely on CSS anchor positioning | With anchor properties ignored (Firefox), the tooltip rendered at `(0, 862)`, off-screen |
| 2 | A late `load_tooltip` reply showed its tooltip after the pointer had left, and the one-shot `mouseleave` handler was already spent | Appeared 3.8s after leaving, never hid |
| 3 | Removing a hovered trigger (LiveView patch, viz re-render) left its tooltip up | Stayed visible indefinitely |
| 4 | Anchored to a 1px div that followed `mousemove`, so it chased the pointer | Moved `180,281 → 251,401` with the cursor |
| 5 | A spinner placeholder appeared for vertices with no tooltip | 150ms timer, round-trip, then nothing |
| 6 | No hover intent or hide delay | 0ms in, 0ms out |
| 7 | Entire moduledocs rendered as markdown | Up to 600×266px |
| 8 | `pointer-events: none` with `overflow: auto` | Clipped content could never be scrolled |
| 9 | No accessibility | Non-focusable `<span>`, no `role="tooltip"`, no `aria-describedby`, no keyboard path |
| 10 | Round-trip per unknown tooltip; stream never trimmed | DOM grew with every hover |
| 11 | Document listeners bound to the first hook instance | A re-mount left them aimed at a detached element |

A second, unrelated hint system — native `title=` attributes on badges, tabs
and icon buttons — looked and behaved differently.

## Decisions (agreed)

1. **A small hint pinned to the element**, not a preview card: vertex name,
   type label and a one-line summary. Rich detail stays in the content panel.
2. **Content rendered inline by the server.** No round-trip, so no spinner, no
   race and no stream. The `TooltipProvider` protocol is unchanged.
3. **JS positioning in the native top layer.** One code path in every browser,
   unit-testable; `popover="manual"` lifts it above any clipping ancestor
   where supported.
4. **One system for both flavours**: vertex hints and plain label hints
   replace every native `title=`.

## Architecture

### Server: `Clarity.Tooltip`

- `attrs/1` — `data-tooltip-*` attributes for a vertex (`title`, `type`,
  optional `text`), a plain label (`text`), or `nil` (none). Spread into the
  trigger: `<.link {Tooltip.attrs(@vertex)}>`.
- `hints/1` — id → hint map for graph visualisations, emitted as
  `data-tooltips` on the `.viz` element. Only vertices with a summary are
  included, since graph node labels already show name and type.
- `summarise/1` — reduces `TooltipProvider` markdown to the first prose
  paragraph as plain text, at most 160 characters on a word boundary. Skips
  identity lines made only of inline code, `Key: value` meta lines, headings
  and lists.

Hints sit on the nearest **focusable** element (the tree/breadcrumb `<a>`, the
`<button>`), so keyboard focus can trigger them. Icon-only buttons gained an
explicit `aria-label`, since their native `title` had been their accessible name.

### Client: `assets/js/tooltip.hook.js`

One controller owns the single `#clarity-tooltip` element (rendered once in
`page_live.html.heex`, `phx-update="ignore"`). The `hidden` attribute is the
single source of truth for visibility.

- Delegated `pointerover` (bubbles) re-derives the trigger on every movement,
  250ms show delay, immediate hide, and a 300ms window after hiding in which the
  next trigger shows at once (so sweeping the tree swaps rather than flickers).
- Focus shows immediately; blur hides. Escape dismisses until the pointer moves
  to a different trigger. Touch pointers are ignored.
- Hides on window exit, capture-phase scroll, resize, window blur and
  `phx:page-loading-start`.
- A `MutationObserver` hides the hint when its trigger leaves the DOM and
  re-renders it when the trigger's `data-tooltip-*` changes (the "Copied!"
  feedback). Mutations inside the tooltip itself are ignored.
- `aria-describedby` is added to the trigger while shown and removed after,
  preserving existing ids.
- `destroyed()` removes every listener and the observer.
- `computePosition/3` places it below and centred, flips above when only that
  fits, then shifts inside the viewport.
- `applyHints/2` copies the `data-tooltips` map onto graphviz `<a>` nodes.

Content is set with `textContent`, never HTML.

### Removed

`Clarity.TooltipComponent` and its template, the `load_tooltip` handlers, the
tooltip stream, `#tooltip-cursor`, `#tooltip-placeholder` and the anchor
positioning CSS.

## Trade-offs

- **Summaries are heuristic.** Auto-trimming hand-written moduledocs reads
  awkwardly for some vertex types; the in-tree impls can be tuned without a
  protocol change, and `usage-rules/vertex-types.md` now asks implementers to
  lead with a sentence.
- **Server cost moves to render time.** About 0.2–0.3ms per vertex (dominated by
  `Code.fetch_docs/1`), so 6–18ms for a typical 20–60-node tree — similar to
  the previous preload, which called `tooltip/1` twice per preloaded vertex.
  Cache if it becomes a problem.
- **Page weight** grows by the inline hints, bounded by the 160-character cap.
- **Disabled buttons** do not receive focus, so the "No editor configured" hint
  is pointer-only — as with the native `title` before.
