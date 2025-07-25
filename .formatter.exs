[
  import_deps: [:phoenix],
  locals_without_parens: [
    ash_atlas: 1,
    ash_atlas: 2,
    atlas_browser_pipeline: 0,
    atlas_browser_pipeline: 1
  ],
  plugins: [Styler, DoctestFormatter, Phoenix.LiveView.HTMLFormatter],
  inputs: ["{mix,.formatter,.credo}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
