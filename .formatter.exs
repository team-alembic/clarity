[
  import_deps: [:ash, :phoenix],
  locals_without_parens: [
    clarity: 1,
    clarity: 2,
    clarity_browser_pipeline: 0,
    clarity_browser_pipeline: 1
  ],
  plugins: [Styler, DoctestFormatter, Phoenix.LiveView.HTMLFormatter],
  inputs: ["{mix,.formatter,.credo}.exs", "{config,lib,test,dev}/**/*.{ex,exs}"]
]
