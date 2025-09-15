defmodule Mix.Tasks.Clarity.Install.Docs do
  @moduledoc false

  @doc false
  @spec short_doc() :: String.t()
  def short_doc, do: "Installs `Clarity`"

  @doc false
  @spec example() :: String.t()
  def example, do: "mix clarity.install"

  @doc false
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
  defmodule Mix.Tasks.Clarity.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    alias Igniter.Code.Common
    alias Igniter.Code.Function
    alias Igniter.Libs.Phoenix
    alias Igniter.Project.Application
    alias Igniter.Project.Formatter
    alias Igniter.Project.Module

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        # Groups allow for overlapping arguments for tasks by the same author
        # See the generators guide for more.
        group: :clarity,
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
        Phoenix.select_router(igniter, "Which router should Clarity be added to?")

      igniter
      |> Formatter.import_dep(:clarity)
      |> add_to_router(app_name, router)
    end

    @spec add_to_router(igniter :: Igniter.t(), app_name :: atom(), router :: module() | nil) ::
            Igniter.t()
    defp add_to_router(igniter, app_name, router)

    defp add_to_router(igniter, _app_name, nil) do
      Igniter.add_warning(igniter, """
      No Phoenix router found or selected. Please ensure that Phoenix is set up
      and then run this installer again with

          mix clarity.install
      """)
    end

    defp add_to_router(igniter, app_name, router) do
      Module.find_and_update_module!(igniter, router, fn zipper ->
        zipper =
          zipper
          |> Common.move_to(&Function.function_call?(&1, :clarity, [1, 2]))
          |> case do
            :error ->
              Common.add_code(
                zipper,
                """
                if Application.compile_env(#{inspect(app_name)}, :dev_routes) do
                  import Clarity.Router

                  scope "/clarity" do
                    pipe_through :browser

                    clarity "/"
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
  end
else
  defmodule Mix.Tasks.Clarity.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'clarity.install' requires igniter. Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
