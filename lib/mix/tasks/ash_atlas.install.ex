defmodule Mix.Tasks.AshAtlas.Install.Docs do
  @moduledoc false

  @spec short_doc() :: String.t()
  def short_doc, do: "Installs `AshAtlas`"

  @spec example() :: String.t()
  def example, do: "mix ash_atlas.install"

  @spec long_doc() :: String.t()
  def long_doc do
    """
    #{short_doc()}

    ## Example

    ```sh
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshAtlas.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    alias Igniter.Code.Common
    alias Igniter.Code.Function
    alias Igniter.Code.Keyword
    alias Igniter.Libs.Phoenix
    alias Igniter.Project.Application
    alias Igniter.Project.Formatter
    alias Igniter.Project.Module

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        # Groups allow for overlapping arguments for tasks by the same author
        # See the generators guide for more.
        group: :ash_atlas,
        # *other* dependencies to add
        # i.e `{:foo, "~> 2.0"}`
        adds_deps: [],
        # *other* dependencies to add and call their associated installers, if they exist
        # i.e `{:foo, "~> 2.0"}`
        installs: [],
        # An example invocation
        example: __MODULE__.Docs.example(),
        # A list of environments that this should be installed in.
        only: nil,
        # a list of positional arguments, i.e `[:file]`
        positional: [],
        # Other tasks your task composes using `Igniter.compose_task`, passing in the CLI argv
        # This ensures your option schema includes options from nested tasks
        composes: [],
        # `OptionParser` schema
        schema: [],
        # Default values for the options in the `schema`
        defaults: [],
        # CLI aliases
        aliases: [],
        # A list of options in the schema that are required
        required: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      app_name = Application.app_name(igniter)

      {igniter, router} =
        Phoenix.select_router(igniter, "Which router should AshAtlas be added to?")

      {igniter, endpoint} =
        Phoenix.select_endpoint(igniter, router, "Which endpoint should AshAtlas be added to?")

      igniter
      |> Formatter.import_dep(:ash_atlas)
      |> add_to_endpoint(endpoint)
      |> add_to_router(app_name, router)
    end

    @spec add_to_router(igniter :: Igniter.t(), app_name :: atom(), router :: module() | nil) ::
            Igniter.t()
    defp add_to_router(igniter, app_name, router)

    defp add_to_router(igniter, _app_name, nil) do
      Igniter.add_warning(igniter, """
      No Phoenix router found or selected. Please ensure that Phoenix is set up
      and then run this installer again with

          mix ash_atlas.install
      """)
    end

    defp add_to_router(igniter, app_name, router) do
      Module.find_and_update_module!(igniter, router, fn zipper ->
        zipper =
          zipper
          |> Common.move_to(&Function.function_call?(&1, :ash_atlas, [1, 2]))
          |> case do
            :error ->
              Common.add_code(
                zipper,
                """
                if Application.compile_env(#{inspect(app_name)}, :dev_routes) do
                  import AshAtlas.Router

                  scope "/atlas" do
                    pipe_through :browser

                    ash_atlas "/"
                  end
                end
                """,
                placement: :after
              )

            _ ->
              zipper
          end

        {:ok, zipper}
      end)
    end

    @spec add_to_endpoint(igniter :: Igniter.t(), endpoint :: module() | nil) ::
            Igniter.t()
    defp add_to_endpoint(igniter, endpoint)

    defp add_to_endpoint(igniter, nil) do
      Igniter.add_warning(igniter, """
      No Phoenix endpoint found or selected. Please ensure that Phoenix is set up
      and then run this installer again with

          mix ash_atlas.install
      """)
    end

    defp add_to_endpoint(igniter, endpoint) do
      Module.find_and_update_module!(igniter, endpoint, fn zipper ->
        zipper
        |> endpoint_move_to_plug(fn zipper ->
          with true <- Common.nodes_equal?(zipper, Plug.Static),
               {:ok, zipper} <- Common.move_right(zipper, 1),
               {:ok, zipper} <- Keyword.get_key(zipper, :from) do
            Common.nodes_equal?(zipper, :ash_atlas)
          else
            _ -> false
          end
        end)
        |> case do
          :error ->
            endpoint_install_plug(zipper)

          {:ok, _zipper} ->
            {:ok, zipper}
        end
      end)
    end

    @spec endpoint_install_plug(zipper :: Sourceror.Zipper.t()) ::
            {:ok, Sourceror.Zipper.t()} | {:warning, String.t()}
    defp endpoint_install_plug(zipper) do
      case endpoint_move_to_plug(zipper, &Common.nodes_equal?(&1, Plug.Static)) do
        {:ok, zipper} ->
          {:ok,
           Common.add_code(
             zipper,
             """
             plug Plug.Static,
               at: "/atlas",
               from: :ash_atlas,
               gzip: true,
               only: AshAtlas.Web.static_paths()
             """,
             placement: :after
           )}

        _ ->
          {:warning,
           """
           The location of the `Plug.Static` plug in your endpoint could not be
           determined. Please ensure that the preinstalled `Plug.Static` plug
           is present in your endpoint or add the following code manually:

               plug Plug.Static,
                 at: "/atlas",
                 from: :ash_atlas,
                 gzip: true,
                 only: AshAtlas.Web.static_paths()
           """}
      end
    end

    @spec endpoint_move_to_plug(
            zipper :: Sourceror.Zipper.t(),
            pred :: (Sourceror.Zipper.t() -> boolean())
          ) :: {:ok, Sourceror.Zipper.t()} | :error
    defp endpoint_move_to_plug(zipper, pred) do
      Common.move_to(zipper, fn zipper ->
        with true <- Function.function_call?(zipper, :plug, 2),
             {:ok, zipper} <- Function.move_to_nth_argument(zipper, 0) do
          pred.(zipper)
        else
          _ -> false
        end
      end)
    end
  end
else
  defmodule Mix.Tasks.AshAtlas.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_atlas.install' requires igniter. Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
