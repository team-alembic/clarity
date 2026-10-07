locals_without_parens = [
  clarity: 1,
  clarity: 2,
  clarity_browser_pipeline: 0,
  clarity_browser_pipeline: 1
]

[
  import_deps: [:ash, :phoenix],
  locals_without_parens: locals_without_parens,
  plugins: [Styler, DoctestFormatter, Phoenix.LiveView.HTMLFormatter],
  inputs: [
    "{mix,.formatter,.credo}.exs",
    "{config,lib,test}/**/*.{ex,exs,heex}",
    "demo/mix.exs",
    "demo/{config,lib}/**/*.{ex,exs,heex}"
  ],
  export: [
    locals_without_parens: locals_without_parens
  ]
]
