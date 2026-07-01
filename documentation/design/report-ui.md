# Design: Report UI (spike)

Status: Draft · 2026-07-02 · branch `spike/report-ui`

## Goal

Offer an alternative to graph navigation: **lens-scoped reports** that roll up
the relevant vertices into a single, top-to-bottom document. For some users,
navigating down a graph is arbitrary and confusing when they just want all the
relevant information in one place. First two reports, both under the **security
lens**:

- **Supply-chain security report** — every dependency with an advisory, an
  outdated version, or a retired version, rolled up with totals.
- **Security posture report** — domains/resources, policy coverage, the who-can
  matrix, sensitive-field exposure, rolled up across the app.

## What already exists (so a report is mostly composition)

- **Supply-chain data**: `Clarity.Status.SupplyChain.statuses/2`,
  `Clarity.Advisory.Source.advisories_for/2`, `Clarity.Dependency.Registry.summary/1`.
- **Posture analysis**: `Clarity.Ash.PolicyAnalysis` (`coverage/2`,
  `actor_profiles/1`, `action_verdict/3`) — all public.
- **Graph query**: `Graph.vertices(clarity.graph, lens.filter)` returns exactly
  the vertices a lens exposes — no `compute_subgraph`/zoom machinery needed.
- **Rendering**: the `<.markdown>` component supports `vertex://` links, so a
  report row can link back into the graph/tree.

A report is: **query the lens's vertices → reuse the per-vertex analysis →
compose one document + a roll-up summary.**

## The UI seam (from the routing map)

The whole app funnels through one LiveView (`Clarity.PageLive`) selected by
`live_action` (`:root | :lens | :vertex | :page`), over routes
`prefix/:lens/:vertex/:content`. `page_live.html.heex` is a monolithic CSS-grid
page, not a reusable wrapper. Reusable chrome: the `<.header>` (logo, status,
lens switcher, theme toggle), the `Setup` `on_mount` (prefix/theme/clarity_pid),
and `LensSwitcherComponent`.

The clean insertion point is a **new `live_action`** under the same `clarity`
router macro — e.g. `prefix/:lens/report` and `prefix/:lens/report/:report_id` —
because a report is lens-scoped but vertex-independent (it skips the
vertex/content redirect chain).

## Proposed approach

- **Route**: add `:report` action(s) in the `clarity` macro. `prefix/:lens/report`
  lists the lens's reports (or opens the first); `prefix/:lens/report/:id` shows
  one.
- **Mode switch**: an Explore ⇄ Report toggle in the header, shown only when the
  active lens has reports. Reuses the lens switcher pattern (`push_patch`).
- **Rendering**: compose static markdown/iodata from the existing analysis,
  rendered through `<.markdown>` with `vertex://` links so any row jumps into the
  graph. Read-only document; no per-report interactivity in the spike.
- **Report list**: the lens's reports as a simple picker (sidebar list or tabs),
  then the selected report body.

## Decisions (agreed)

1. **Sibling `Clarity.ReportLive`** — a separate page LiveView under the same
   `live_session`, reusing `Setup` (on_mount), `<.header>`, and the lens
   switcher. Keeps report code clear of PageLive's graph/zoom/tree state.
2. **`Clarity.Report` extension point now** — a registered behaviour, consistent
   with content/status providers. A report declares its name, which lens(es) it
   applies to, and renders interactive content.
3. **Interactive reports** — each report is a **LiveComponent** (like interactive
   content providers), so it can filter/sort/expand. `ReportLive` embeds the
   selected report and passes it the graph + lens. Rows still use `vertex://`
   links back into the graph.
4. **Header toggle (Explore | Reports)** — a segmented control in `<.header>`,
   shown only when the active lens has ≥1 applicable report. Switches the whole
   view via `push_patch`, reusing the lens-switcher navigation pattern.

## Architecture

- **`Clarity.Report`** (behaviour): `name/0`, `description/0` (optional),
  `applies?/1` (given a `Lens`, is this report offered?). The module also
  `use`s the LiveComponent macro and implements `update/2` + `render/1`
  (+ `handle_event/3`), receiving `graph` and `lens` assigns. Registered via
  `:clarity_reports`; discovered by `Clarity.Config.list_reports/0`.
- **Router**: new actions in the `clarity` macro — `prefix/:lens/report`
  (report index / first report) and `prefix/:lens/report/:report_id` (one
  report).
- **`Clarity.ReportLive`**: resolves the lens, lists reports where
  `applies?(lens)`, renders a picker + the selected report LiveComponent. Fetches
  `clarity.graph` via `Clarity.get/2` and queries `Graph.vertices(graph,
  lens.filter)`.
- **Header toggle**: Explore links to the current lens's vertex view; Reports
  links to `prefix/:lens/report`. Only shown when the lens has reports.

## Phasing

1. `Clarity.Report` behaviour + `Config.list_reports/0` + registration.
2. `ReportLive` + `:report` routes + report picker + header Explore/Reports
   toggle (with one minimal report to prove the seam end-to-end).
3. Supply-chain security report (interactive: filter by severity/status, sortable
   affected-deps table, roll-up header, freshness).
4. Security posture report (per-domain resources, who-can matrix, sensitive-field
   exposure, roll-up header).
5. Tests + `usage-rules/reports.md` + rebuild assets.

## The two reports (content sketch)

### Supply-chain security

Roll-up header: "N advisories across M dependencies · X outdated · Y retired",
freshness timestamp. Then a table of affected deps (name, installed, latest,
severity, fixed-in), each linking to its `Vertex.Application` / `Vertex.Advisory`.

### Security posture

Roll-up header: domains, resources, unprotected/bypass counts. Then per domain:
resources with their enforcement summary, the who-can action matrix, and
sensitive-field exposure — each resource linking to its vertex.

## Risks / unknowns

- **Performance**: a report iterates all lens vertices and runs analysis per
  vertex. Bounded (apps ~dozens; resources ~dozens) and off the async graph
  path; measure if it grows.
- **Report ↔ graph coherence**: `vertex://` links must resolve under the same
  lens; the report is a view over the same graph, so this should hold.
- **Scope creep**: keep the spike to two static reports + the mode switch; defer
  export (PDF/print), scheduling, and interactivity.
