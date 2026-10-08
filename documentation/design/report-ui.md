# Design: Report UI (spike)

Status: Draft · 2026-07-02 · revised 2026-10-08 (reports became a top-level section)

## Goal

Offer an alternative to graph navigation: **reports** that roll up the relevant
vertices into a single, top-to-bottom document. For some users, navigating down
a graph is arbitrary and confusing when they just want all the relevant
information in one place. The first two reports:

- **Supply-chain security report** — every dependency with an advisory, an
  outdated version, or a retired version, rolled up with totals.
- **Security posture report** — domains/resources, policy coverage, the who-can
  matrix, sensitive-field exposure, rolled up across the app.

## What already exists (so a report is mostly composition)

- **Supply-chain data**: `Clarity.Status.SupplyChain.statuses/2`,
  `Clarity.Advisory.Source.advisories_for/2`, `Clarity.Dependency.Registry.summary/1`.
- **Posture analysis**: `Clarity.Ash.PolicyAnalysis` (`coverage/2`,
  `actor_profiles/1`, `action_verdict/3`) — all public.
- **Graph query**: `Graph.vertices(graph, query)` returns the vertices a report
  needs — no `compute_subgraph`/zoom machinery needed. (A lens's `filter` can be
  a function of the graph, so it isn't always a query `Graph.vertices/2` takes.)
- **Rendering**: the `<.markdown>` component supports `vertex://` links, so a
  report could link back into the graph/tree; the prose reports don't.

A report is: **query the graph → reuse the per-vertex analysis → compose one
document + a roll-up summary.**

## The UI seam (from the routing map)

The whole app funnels through one LiveView (`Clarity.PageLive`) selected by
`live_action` (`:root | :lens | :vertex | :page`), over routes
`prefix/:lens/:vertex/:content`. `page_live.html.heex` is a monolithic CSS-grid
page, not a reusable wrapper. Reusable chrome: the `<.header>` (logo, status,
lens switcher, theme toggle), the `Setup` `on_mount` (prefix/theme/clarity_pid),
and `LensSwitcherComponent`.

The clean insertion point is a **new `live_action`** under the same `clarity`
router macro, because a report is vertex-independent (it skips the
vertex/content redirect chain). The routes are now `prefix/:lens/reports` and
`prefix/:lens/reports/:report_id` (see decision 4).

## Original proposal

Superseded in part by the decisions below.

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
   with content/status providers. A report declares its name and an optional
   description, and renders its content.
3. **Reports are prose** (revised). They were first built interactive
   (filter/sort/expand) and cross-linked to vertices, but a report reads better as
   *prose that explains what's going on*: narrative markdown with the data woven
   into sentences and the "why it matters" spelled out — not a dashboard to
   operate, and not cross-linking away. Each report is still a **LiveComponent**
   (embedded by `ReportLive` with graph + lens), but it renders generated markdown
   via `<.markdown>` with no interactivity and no `vertex://` links.

   Each report opens with an **executive dashboard** above the prose — KPI stat
   cards and stacked bars of proportions, both plain HTML and Tailwind (no
   JavaScript). Shared components live in `Clarity.Report.Charts` (`stat/1`,
   `stacked_bar/1`).
4. **Reports are a top-level section** (revised). The spike first scoped each
   report to a lens with `applies?/1` and switched views with an Explore |
   Reports toggle shown only when the lens had reports, so the supply-chain and
   posture reports existed only under the Security lens, where nobody would
   think to look. A lens is a role's named, filtered view of the graph; a report
   is something else, and key reports must not be hidden behind a lens choice.
   (Making Reports a lens of its own was tried and dropped for the same reason:
   it isn't a filter.) The header now has **Explore** and **Reports** as
   top-level menu items under every lens, and Reports lists every registered
   report whatever the lens. The lens stays in the URL, so Explore returns to it;
   a lens may later order or filter a report's contents for its role, but never
   hide a report.

## Architecture

- **`Clarity.Report`** (behaviour): `name/0`, `description/0` (optional). The
  module also `use`s the LiveComponent macro and implements `update/2` +
  `render/1`, receiving `graph` (unfiltered), `lens` (the current lens),
  `prefix` and `version` assigns. Registered via `:clarity_reports`; discovered
  by `Clarity.Config.list_reports/0`.
- **Router**: `prefix/:lens/reports` (opens the first report) and
  `prefix/:lens/reports/:report_id`, with the literal `reports` segment ahead of
  `prefix/:lens/:vertex`.
- **`Clarity.ReportLive`**: lists every report as a tab and embeds the selected
  one; an unknown lens moves to the default lens's reports. Fetches
  `clarity.graph` via `Clarity.get/2`, and fetches it again when introspection
  starts or finishes, passing the graph's update count as `version` so the
  report re-renders.
- **Header**: Explore and Reports as top-level menu items (`section` attr marks
  the current one). The lens switcher patches within the current section; on
  the reports page it keeps the report shown.

## Phasing

All phases implemented.

1. **(done)** `Clarity.Report` behaviour + `Config.list_reports/0` + registration.
2. **(done)** `ReportLive` + `:report` routes + report picker + header
   Explore/Reports toggle (since replaced by top-level menu items).
3. **(done)** Supply-chain security report — prose: an overview sentence, then
   narrative sections for security advisories (per affected dep, with fix
   availability and summaries) and dependency hygiene (retired/outdated).
4. **(done)** Security posture report — prose: an overview sentence, then
   narrative sections for open resources, bypass policies, and sensitive-field
   exposure. (The per-action who-can matrix stays in the resource's Security tab.)
5. **(done)** Component + `ReportLive` integration tests + `usage-rules/reports.md`.

Deviation from the sketch: the posture report is a per-resource table (not
grouped by domain), and the full who-can matrix stays in the per-resource
`SecurityOverview` content rather than being duplicated into the report.
Grouping by domain and embedding the matrix are natural follow-ups.

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
- **Scope creep**: keep the spike to two static reports + the Reports section;
  defer export (PDF/print), scheduling, and interactivity.
