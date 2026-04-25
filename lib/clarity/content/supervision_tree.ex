defmodule Clarity.Content.SupervisionTree do
  @moduledoc """
  D2 diagram showing the runtime supervision tree of an OTP application.

  Walks `:application_controller.get_master/1` and `:supervisor.which_children/1`
  to discover the live tree. Supervisors render as `package` containers,
  workers as rectangles. If the application is not running the diagram
  shows a single placeholder node explaining why.

  Worker labels link back to their `Clarity.Vertex.Module` so users can
  navigate to the module from the diagram.
  """

  @behaviour Clarity.Content

  alias Clarity.Content.D2.Helpers
  alias Clarity.Vertex.Application
  alias Clarity.Vertex.Module, as: ModuleVertex

  @impl Clarity.Content
  def name, do: "Supervision Tree"

  @impl Clarity.Content
  def description, do: "Live supervision tree for this OTP application"

  @impl Clarity.Content
  def sort_priority, do: -70

  @impl Clarity.Content
  def applies?(%Application{app: app}, _lens) do
    case app_root_supervisor(app) do
      {:ok, _pid} -> true
      :error -> false
    end
  end

  def applies?(_vertex, _lens), do: false

  @impl Clarity.Content
  def render_static(%Application{app: app}, _lens) do
    {:d2, fn _props -> to_d2(app) end}
  end

  @spec to_d2(atom()) :: iodata()
  defp to_d2(app) do
    case app_root_supervisor(app) do
      {:ok, root_pid} ->
        root_label = Atom.to_string(app)

        [
          "direction: down\n",
          render_subtree("root", root_label, root_pid, "")
        ]

      :error ->
        [
          "direction: down\n",
          "not_running: \"",
          Atom.to_string(app),
          " is not currently running\" { shape: rectangle }\n"
        ]
    end
  end

  @spec render_subtree(String.t(), String.t(), pid(), String.t()) :: iodata()
  defp render_subtree(id, label, pid, indent) do
    children = safe_children(pid)
    child_indent = indent <> "  "

    body =
      children
      |> Enum.with_index()
      |> Enum.map(fn {{child_id_atom, child_pid, type, modules}, idx} ->
        child_id = id <> "_" <> Integer.to_string(idx)
        render_child(child_id, child_id_atom, child_pid, type, modules, child_indent)
      end)

    edges =
      children
      |> Enum.with_index()
      |> Enum.map(fn {_child, idx} ->
        child_id = id <> "_" <> Integer.to_string(idx)
        [indent, "  ", id, " -> ", id, ".", child_id, "\n"]
      end)

    [
      indent,
      id,
      ": ",
      Helpers.quoted(label),
      " {\n",
      indent,
      "  shape: package\n",
      body,
      edges,
      indent,
      "}\n"
    ]
  end

  @spec render_child(
          String.t(),
          term(),
          pid() | :restarting | :undefined,
          atom(),
          term(),
          String.t()
        ) ::
          iodata()
  defp render_child(child_id, child_id_atom, child_pid, type, modules, indent) do
    label = child_label(child_id_atom, modules)
    primary_module = primary_module(modules)

    link =
      case primary_module do
        nil -> []
        mod -> [indent, "  link: \"", Helpers.vertex_link(ModuleVertex, [mod]), "\"\n"]
      end

    case {type, child_pid} do
      {:supervisor, pid} when is_pid(pid) ->
        render_subtree(child_id, label, pid, indent)

      _ ->
        [
          indent,
          child_id,
          ": ",
          Helpers.quoted(label),
          " {\n",
          indent,
          "  shape: rectangle\n",
          link,
          indent,
          "}\n"
        ]
    end
  end

  @spec child_label(term(), term()) :: String.t()
  defp child_label(id, modules) do
    case primary_module(modules) do
      nil -> inspect(id)
      mod -> Helpers.short_name(mod)
    end
  end

  @spec primary_module(term()) :: module() | nil
  defp primary_module([mod | _]) when is_atom(mod), do: mod
  defp primary_module(mod) when is_atom(mod) and not is_nil(mod), do: mod
  defp primary_module(_), do: nil

  @spec safe_children(pid()) :: [{term(), pid() | :restarting | :undefined, atom(), term()}]
  defp safe_children(pid) do
    Supervisor.which_children(pid)
  catch
    _, _ -> []
  end

  @spec app_root_supervisor(atom()) :: {:ok, pid()} | :error
  defp app_root_supervisor(app) do
    case :application_controller.get_master(app) do
      :undefined ->
        :error

      master when is_pid(master) ->
        case :application_master.get_child(master) do
          {pid, _module} when is_pid(pid) -> {:ok, pid}
          _ -> :error
        end
    end
  catch
    _, _ -> :error
  end
end
