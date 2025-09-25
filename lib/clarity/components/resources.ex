defmodule Clarity.Resources do
  @moduledoc false

  use Phoenix.Component

  import Phoenix.HTML

  alias Phoenix.LiveView.Rendered
  alias Phoenix.LiveView.Socket

  phoenix_js_paths =
    for app <- ~w(phoenix phoenix_live_view)a do
      extension = if Mix.env() == :prod, do: ".min.js", else: ".js"
      path = Application.app_dir(app, ["priv", "static", "#{app}#{extension}"])
      Module.put_attribute(__MODULE__, :external_resource, path)
      path
    end

  static_path = Application.app_dir(:clarity, ["priv", "static"])

  @external_resource cache_static_manifest_path =
                       Application.app_dir(:clarity, "priv/static/cache_manifest.json")

  manifest =
    if File.exists?(cache_static_manifest_path) do
      cache_static_manifest_path
      |> File.read!()
      |> JSON.decode!()
      |> Map.fetch!("latest")
    else
      %{}
    end

  @external_resource js_path =
                       Path.join([
                         static_path,
                         Map.get(manifest, "assets/app.js", "assets/app.js")
                       ])
  @external_resource css_path =
                       Path.join([
                         static_path,
                         Map.get(manifest, "assets/app.css", "assets/app.css")
                       ])
  @external_resource logo_path =
                       Path.join([
                         static_path,
                         Map.get(
                           manifest,
                           "images/logo.svg",
                           "images/logo.svg"
                         )
                       ])

  @doc """
  Renders the CSS required for Clarity.
  """
  @spec css(assigns :: Socket.assigns()) :: Rendered.t()
  def css(assigns) do
    ~H"""
    <style type="text/css">
      <%= raw(resource(:css)) %>
    </style>
    """
  end

  @doc """
  Renders the JS required for Clarity.
  """
  @spec js(assigns :: Socket.assigns()) :: Rendered.t()
  def js(assigns) do
    ~H"""
    <script defer type="text/javascript">
      <%= raw(resource(:js)) %>
    </script>
    """
  end

  @doc """
  Returns the logo URI for Clarity.
  """
  @spec logo_uri() :: iodata()
  # sobelow_skip ["Traversal"]
  def logo_uri, do: ["data:image/svg+xml;base64,", unquote(Base.encode64(File.read!(logo_path)))]

  @spec resource(:js | :css) :: String.t()
  defp resource(type)

  # sobelow_skip ["Traversal"]
  defp resource(:js),
    do:
      unquote("""
      #{for path <- phoenix_js_paths, do: path |> File.read!() |> String.replace("//# sourceMappingURL=", "// ")}
      #{File.read!(js_path)}
      """)

  # sobelow_skip ["Traversal"]
  defp resource(:css), do: unquote(File.read!(css_path))
end
