# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v0.5.0](https://github.com/team-alembic/clarity/compare/v0.4.0...v0.5.0) (2026-06-05)




### Features:

* Add sort_priority to content providers for deterministic tab ordering by [@C-Sinclair](https://github.com/C-Sinclair)

* show raw source content for md, mermaid, graphviz tabs by [@joshprice](https://github.com/joshprice)

### Bug Fixes:

* LiveView 1.2.0-rc.0 compatibility by [@frankdugan3](https://github.com/frankdugan3)

* Hide backtick characters on inline code in prose content by Robert Ellen

* test module name no longer breaks tests by [@joshprice](https://github.com/joshprice)

* correct swapped ack/nack warning strings and silence stale-ack tests by [@joshprice](https://github.com/joshprice)

* use CSS to remove Typography backticks instead of AST transform by [@joshprice](https://github.com/joshprice)

* Speed up test suite: replace Process.sleep with sync barriers, exclude slow tests by [@joshprice](https://github.com/joshprice)

* replace Process.sleep with :sys.get_state sync barriers in by [@joshprice](https://github.com/joshprice)

* Replace racy receive-in-handle_call mock with deterministic queue by [@joshprice](https://github.com/joshprice)

* resolve infinite loop of summary toggling in left sidebar by [@C-Sinclair](https://github.com/C-Sinclair)

* Fix editor button crash when editor binary doesn't exist by [@C-Sinclair](https://github.com/C-Sinclair)

* Stay on Graph Navigation tab when clicking nodes by [@C-Sinclair](https://github.com/C-Sinclair)

* prevent spurious detail toggles, tooltip flicker, and tree loading spinner by [@joshprice](https://github.com/joshprice)

* load flickering and tooltip errors by [@joshprice](https://github.com/joshprice)

### Performance Improvements:

* Fix StatusLive tests taking 38s by removing unused receive timeout in mock by [@joshprice](https://github.com/joshprice)
