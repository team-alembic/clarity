defmodule Clarity.Resources do
  @moduledoc false

  use Phoenix.Component

  import Phoenix.HTML

  alias Phoenix.LiveView.Rendered
  alias Phoenix.LiveView.Socket

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

  @external_resource logo_path =
                       Path.join([
                         static_path,
                         Map.get(
                           manifest,
                           "images/logo.svg",
                           "images/logo.svg"
                         )
                       ])
  @external_resource splash_path =
                       Path.join([
                         static_path,
                         Map.get(
                           manifest,
                           "images/splash.svg",
                           "images/splash.svg"
                         )
                       ])

  @doc """
  Renders the splash screen artwork inline.
  """
  @spec splash_svg(assigns :: Socket.assigns()) :: Rendered.t()
  # Inlines Clarity's own splash SVG, embedded from priv at compile time.
  # sobelow_skip ["XSS.Raw"]
  def splash_svg(assigns) do
    ~H"""
    {raw(splash())}
    """
  end

  @doc """
  Returns the logo URI for Clarity.
  """
  @spec logo_uri() :: iodata()
  # sobelow_skip ["Traversal"]
  def logo_uri, do: ["data:image/svg+xml;base64,", unquote(Base.encode64(File.read!(logo_path)))]

  @doc """
  Returns the splash screen logo SVG content for Clarity.
  """
  @spec splash() :: String.t()
  # sobelow_skip ["Traversal"]
  def splash, do: unquote(File.read!(splash_path))
end
