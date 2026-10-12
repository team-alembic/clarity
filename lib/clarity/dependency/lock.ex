defmodule Clarity.Dependency.Lock do
  @moduledoc """
  Which applications are Hex packages, and under which name, read from the
  project's `mix.lock`.

  Version status and advisories are looked up by Hex package name. An
  application isn't one just because a package shares its name: the project's
  own applications, and path and git dependencies, are not Hex packages, though
  Hex may have an unrelated package called the same (a project called
  `alembic`, say). And a dependency's package can be named apart from its
  application (`hex: :other_name`). The lockfile says which is which.

  Without a lockfile, as in a release, the applications Clarity knows to be the
  project's are not packages, and any other is taken to be the package of its
  name.
  """

  alias Clarity.Config

  @lock {__MODULE__, :lock}

  @doc """
  The Hex package `app` is installed from, or `nil` when it isn't one.
  """
  @spec hex_package(atom()) :: String.t() | nil
  def hex_package(app) when is_atom(app) do
    case read() do
      nil -> if !project_app?(app), do: to_string(app)
      lock -> lock |> Map.get(app) |> package()
    end
  end

  @spec package(tuple() | nil) :: String.t() | nil
  defp package(entry) when is_tuple(entry) and elem(entry, 0) == :hex,
    do: to_string(elem(entry, 1))

  defp package(_entry), do: nil

  @spec project_app?(atom()) :: boolean()
  defp project_app?(app) do
    case Config.project_applications() do
      :all -> false
      apps -> app in apps
    end
  end

  # The lockfile, read again only when it changes.
  @spec read() :: %{atom() => tuple()} | nil
  defp read do
    with path when is_binary(path) <- path(),
         {:ok, %File.Stat{mtime: mtime}} <- File.stat(path) do
      case :persistent_term.get(@lock, nil) do
        {^path, ^mtime, lock} ->
          lock

        _stale ->
          lock = parse(path)
          :persistent_term.put(@lock, {path, mtime, lock})
          lock
      end
    else
      _none -> nil
    end
  end

  @spec path() :: Path.t() | nil
  defp path do
    case Config.lockfile() do
      nil -> mix_lockfile()
      path -> Path.expand(path)
    end
  end

  @spec mix_lockfile() :: Path.t() | nil
  defp mix_lockfile do
    if Code.ensure_loaded?(Mix.Project) and Mix.Project.get() do
      Path.expand(Mix.Project.config()[:lockfile] || "mix.lock")
    end
  rescue
    _error -> nil
  end

  # As Mix reads it: a map of literals.
  @spec parse(Path.t()) :: %{atom() => tuple()} | nil
  defp parse(path) do
    opts = [file: path, emit_warnings: false]

    with {:ok, contents} <- File.read(path),
         {:ok, quoted} <- Code.string_to_quoted(contents, opts),
         {%{} = lock, _binding} <- Code.eval_quoted(quoted, [], opts) do
      lock
    else
      _unreadable -> nil
    end
  end
end
