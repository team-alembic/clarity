[
  import_deps: [:ash, :phoenix],
  locals_without_parens: [
    atlas: 1,
    atlas: 2,
    atlas_browser_pipeline: 0,
    atlas_browser_pipeline: 1
  ],
  plugins: [Styler, DoctestFormatter, Phoenix.LiveView.HTMLFormatter],
  inputs: ["{mix,.formatter,.credo}.exs", "{config,lib,test,dev}/**/*.{ex,exs}"]
]
