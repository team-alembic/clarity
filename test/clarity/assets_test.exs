defmodule Clarity.AssetsTest do
  use Clarity.Test.ConnCase, async: true

  alias Clarity.Assets

  @assets Application.app_dir(:clarity, "priv/static/assets")

  describe "a page" do
    test "links its CSS and JS rather than inlining them", %{conn: conn} do
      html = conn |> get("/clarity/debug/root/graph") |> html_response(200)
      document = LazyHTML.from_document(html)

      assert [
               "/clarity/assets/phoenix.js?vsn=" <> _,
               "/clarity/assets/app.js?vsn=" <> _
             ] = document |> LazyHTML.query("script[src]") |> LazyHTML.attribute("src")

      assert document |> LazyHTML.query("script[type=module]") |> LazyHTML.attribute("src") ==
               [Assets.path("/clarity", "app.js")]

      assert document |> LazyHTML.query("link[rel=stylesheet]") |> LazyHTML.attribute("href") ==
               [Assets.path("/clarity", "app.css")]

      # Only small inline scripts remain, if any: no bundle.
      assert document |> LazyHTML.query("script:not([src])") |> LazyHTML.text() |> byte_size() <
               1_000
    end
  end

  describe "the asset route" do
    test "serves Clarity's JS entry, kept until Clarity changes", %{conn: conn} do
      conn = get(conn, Assets.path("/clarity", "app.js"))

      assert response(conn, 200) == File.read!(Path.join(@assets, "app.js"))
      assert response_content_type(conn, :js) =~ "text/javascript"
      assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000, immutable"]
    end

    # A host's :browser pipeline protects from forgery, which refuses JS to a
    # plain GET (a <script> tag's) as cross-origin unless told otherwise.
    # Phoenix.ConnTest tells it otherwise for every test, so this one doesn't.
    test "serves JS through a pipeline that protects from forgery", %{conn: conn} do
      conn =
        conn
        |> put_private(:plug_skip_csrf_protection, false)
        |> get(Assets.path("/clarity", "app.js"))

      assert response(conn, 200) == File.read!(Path.join(@assets, "app.js"))
    end

    test "serves the CSS", %{conn: conn} do
      conn = get(conn, Assets.path("/clarity", "app.css"))

      assert response(conn, 200) == File.read!(Path.join(@assets, "app.css"))
      assert response_content_type(conn, :css) =~ "text/css"
    end

    test "serves the host's Phoenix and LiveView JS", %{conn: conn} do
      conn = get(conn, Assets.path("/clarity", "phoenix.js"))

      assert response(conn, 200) =~ "LiveSocket"
      assert response_content_type(conn, :js) =~ "text/javascript"
    end

    test "revalidates an entry asked for without its digest", %{conn: conn} do
      conn = get(conn, "/clarity/assets/app.js")

      assert response(conn, 200)
      assert get_resp_header(conn, "cache-control") == ["no-cache"]
    end

    test "serves a chunk, whose name changes with its content, to keep", %{conn: conn} do
      [chunk | _] = @assets |> Path.join("chunks/*.js") |> Path.wildcard()

      conn = get(conn, "/clarity/assets/chunks/" <> Path.basename(chunk))

      assert response(conn, 200) == File.read!(chunk)
      assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000, immutable"]
    end

    test "serves the gzipped file to a browser that accepts it", %{conn: conn} do
      conn = conn |> put_req_header("accept-encoding", "gzip, br") |> get(Assets.path("/clarity", "app.js"))

      assert get_resp_header(conn, "content-encoding") == ["gzip"]
      assert :zlib.gunzip(response(conn, 200)) == File.read!(Path.join(@assets, "app.js"))
    end

    for path <- [
          "/clarity/assets/nope.js",
          "/clarity/assets/chunks/nope.js",
          "/clarity/assets/..%2Fapp.js",
          "/clarity/assets/chunks/..%2F..%2F..%2Fmix.exs",
          "/clarity/assets/images/logo.svg",
          "/clarity/assets/.hidden.js"
        ] do
      test "refuses #{path}", %{conn: conn} do
        assert conn |> get(unquote(path)) |> response(404)
      end
    end
  end

  describe "path/2" do
    test "names an entry with the digest of its content" do
      assert "/clarity/assets/app.js?vsn=" <> vsn = Assets.path("/clarity", "app.js")
      assert vsn =~ ~r/\A[0-9a-f]{12}\z/
      assert Assets.path("/", "app.css") =~ ~r"\A/assets/app\.css\?vsn=[0-9a-f]{12}\z"
    end
  end
end
