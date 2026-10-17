defmodule Clarity.Assets do
  @moduledoc false

  # Serves Clarity's assets to its pages, at `prefix/assets/*path` (see
  # `Clarity.Router.clarity/2`):
  #
  #   * `phoenix.js`, the host's Phoenix and LiveView JS, at its versions
  #   * `app.css`, Clarity's CSS
  #   * `app.js`, Clarity's JS, and the chunks it imports as it needs them
  #     (`chunks/*.js`): Mermaid, each kind of Mermaid diagram, and Graphviz
  #
  # A page asks for each entry with the digest of its content (`path/2`), and
  # a chunk's name carries one, so browsers keep them until Clarity changes.
  #
  # Clarity ships them built, in priv/static/assets. While developing Clarity
  # itself, the demo app's watchers rebuild them into a separate, gitignored
  # directory (`config :clarity, :assets_path`), and they are served from there
  # without caching.

  @behaviour Plug

  import Plug.Conn

  alias Clarity.Resources.AssetPath

  phoenix_js_paths =
    for app <- ~w(phoenix phoenix_live_view)a do
      extension = if Mix.env() == :prod, do: ".min.js", else: ".js"
      path = Application.app_dir(app, ["priv", "static", "#{app}#{extension}"])
      @external_resource path
      path
    end

  @phoenix_js Enum.map_join(phoenix_js_paths, "\n", fn path ->
                path |> File.read!() |> String.replace("//# sourceMappingURL=", "// ")
              end)

  @shipped_dir Application.app_dir(:clarity, ["priv", "static", "assets"])
  @dev_dir Application.compile_env(:clarity, :assets_path)

  @entries ~w(app.js app.css)

  # Recompile when an entry changes, so its digest follows it.
  for entry <- @entries do
    @external_resource AssetPath.pick(@dev_dir, entry, Path.join(@shipped_dir, entry))
  end

  digest = fn content ->
    :md5 |> :crypto.hash(content) |> Base.encode16(case: :lower) |> binary_part(0, 12)
  end

  @digests Map.new(
             [{"phoenix.js", @phoenix_js}] ++
               for entry <- @entries do
                 path = AssetPath.pick(@dev_dir, entry, Path.join(@shipped_dir, entry))
                 {entry, if(File.exists?(path), do: File.read!(path), else: "")}
               end,
             fn {entry, content} -> {entry, digest.(content)} end
           )

  @forever "public, max-age=31536000, immutable"

  @content_types %{
    ".js" => "text/javascript",
    ".css" => "text/css",
    ".map" => "application/json"
  }

  @doc """
  The path to `entry` (`"app.js"`, `"app.css"` or `"phoenix.js"`) under
  Clarity's `prefix`, with its digest.
  """
  @spec path(String.t(), String.t()) :: String.t()
  def path(prefix, entry) when is_map_key(@digests, entry),
    do: Path.join([prefix, "assets", entry]) <> "?vsn=" <> @digests[entry]

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{path_params: %{"path" => path}} = conn, _opts) do
    case file(path) do
      {:ok, file} -> conn |> fetch_query_params() |> serve(file)
      :error -> conn |> send_resp(404, "Not found") |> halt()
    end
  end

  # Only the entries and the chunks, by plain names: never a path out of the
  # assets directory.
  @spec file([String.t()]) :: {:ok, {:memory, String.t()} | {:disk, Path.t()}} | :error
  defp file(["phoenix.js"]), do: {:ok, {:memory, "phoenix.js"}}
  defp file([name]) when name in @entries, do: on_disk(name)
  defp file([name]) when name in ~w(app.js.map app.css.map), do: on_disk(name)
  defp file(["chunks", name]), do: if(plain?(name), do: on_disk("chunks/" <> name), else: :error)
  defp file(_path), do: :error

  @spec plain?(String.t()) :: boolean()
  defp plain?(name),
    do: name =~ ~r/\A[\w-][\w.-]*\.js(\.map)?\z/ and not String.contains?(name, "..")

  # sobelow_skip ["Traversal.FileModule"]
  @spec on_disk(String.t()) :: {:ok, {:disk, Path.t()}} | :error
  defp on_disk(relative) do
    path = AssetPath.pick(@dev_dir, relative, Path.join(@shipped_dir, relative))
    if File.regular?(path), do: {:ok, {:disk, path}}, else: :error
  end

  @spec serve(Plug.Conn.t(), {:memory, String.t()} | {:disk, Path.t()}) :: Plug.Conn.t()
  defp serve(conn, {:memory, "phoenix.js"}) do
    conn
    |> headers("phoenix.js")
    |> send_resp(200, @phoenix_js)
    |> halt()
  end

  # Only Clarity's own built assets, as JS or CSS, from paths file/1 allows.
  # sobelow_skip ["XSS.SendResp", "Traversal.SendFile"]
  defp serve(conn, {:disk, path}) do
    conn = headers(conn, path)

    if gzip?(conn) do
      conn
      |> put_resp_header("content-encoding", "gzip")
      |> put_resp_header("vary", "accept-encoding")
      |> send_resp(200, gzipped(path))
      |> halt()
    else
      conn |> send_file(200, path) |> halt()
    end
  end

  # Gzipped once per file and kept: the shipped files never change while
  # Clarity runs, and a page loads only a few of them.
  # sobelow_skip ["Traversal.FileModule"]
  @spec gzipped(Path.t()) :: binary()
  defp gzipped(path) do
    key = {__MODULE__, :gzipped, path}

    with nil <- :persistent_term.get(key, nil) do
      gzipped = :zlib.gzip(File.read!(path))
      :persistent_term.put(key, gzipped)
      gzipped
    end
  end

  # The content type comes from @content_types, never the request.
  @spec headers(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  # sobelow_skip ["XSS.ContentType"]
  defp headers(conn, path) do
    conn
    |> put_resp_content_type(Map.fetch!(@content_types, Path.extname(path)))
    |> put_resp_header("cache-control", cache_control(conn, path))
  end

  # The dev build changes as Clarity is developed, so it is never kept.
  @spec cache_control(Plug.Conn.t(), String.t()) :: String.t()
  defp cache_control(conn, path) do
    cond do
      dev_build?() -> "no-cache"
      String.contains?(path, "/chunks/") -> @forever
      conn.query_params["vsn"] == @digests[Path.basename(path)] -> @forever
      true -> "no-cache"
    end
  end

  # Not the dev build, which changes as Clarity is developed.
  @spec gzip?(Plug.Conn.t()) :: boolean()
  defp gzip?(conn), do: not dev_build?() and accepts_gzip?(conn)

  # Whether the demo app's watchers have built Clarity's assets, to serve
  # in place of the shipped ones. Read when serving, not compiled in, as the
  # build appears once the watchers have run.
  @spec dev_build?() :: boolean()
  defp dev_build? do
    case Application.get_env(:clarity, :assets_path) do
      nil -> false
      dir -> File.exists?(Path.join(dir, "app.js"))
    end
  end

  @spec accepts_gzip?(Plug.Conn.t()) :: boolean()
  defp accepts_gzip?(conn) do
    conn
    |> get_req_header("accept-encoding")
    |> Enum.any?(&String.contains?(&1, "gzip"))
  end
end
