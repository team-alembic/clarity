defmodule Clarity.SourceLocation do
  @moduledoc """
  Represents source location information with application and module context.

  This module centralizes the handling of source location data, eliminating
  redundant application lookups and file path parsing. It provides a structured
  way to store and access source information including application, module,
  and annotation data.

  ## Examples

      # From module with annotation
      source_location = SourceLocation.from_module_anno(MyModule, anno)

      # From module without annotation (line 1)
      source_location = SourceLocation.from_module(MyModule)

      # From application and file path
      source_location = SourceLocation.from_path(:my_app, "/path/to/file.ex")

      # Extract information
      file_path = SourceLocation.file_path(source_location)
      line = SourceLocation.line(source_location)

  """

  alias Spark.Dsl.Entity

  @enforce_keys [:anno]
  defstruct [:application, :module, :anno]

  @type t() :: %__MODULE__{
          application: Application.app() | nil,
          module: module() | nil,
          anno: :erl_anno.anno()
        }

  @doc """
  Creates a SourceLocation from a module and annotation.

  Uses `Application.get_application/1` to determine the application
  the module belongs to.

  ## Examples

      iex> anno = :erl_anno.set_file('lib/my_module.ex', :erl_anno.new(42))
      ...> SourceLocation.from_module_anno(MyModule, anno)
      %SourceLocation{application: :my_app, module: MyModule, anno: anno}

  """
  @spec from_module_anno(module(), :erl_anno.anno()) :: t()
  def from_module_anno(module, anno) do
    application = Application.get_application(module)

    %__MODULE__{
      application: application,
      module: module,
      anno: anno
    }
  end

  @doc """
  Creates a SourceLocation from an application and annotation.

  The module field will be set to `nil` since we only have
  application context.

  ## Examples

      iex> anno = :erl_anno.set_file('lib/some_file.ex', :erl_anno.new(10))
      ...> SourceLocation.from_application_anno(:my_app, anno)
      %SourceLocation{application: :my_app, module: nil, anno: anno}

  """
  @spec from_application_anno(Application.app(), :erl_anno.anno()) :: t()
  def from_application_anno(application, anno) do
    %__MODULE__{
      application: application,
      module: nil,
      anno: anno
    }
  end

  @doc """
  Creates a SourceLocation from a module without annotation.

  This is useful when you have module information but no specific
  line/location details. The annotation will be created with line 1
  and the module's source file if available.

  ## Examples

      iex> SourceLocation.from_module(MyModule)
      %SourceLocation{application: :my_app, module: MyModule, anno: anno}

  """
  @spec from_module(module()) :: t()
  def from_module(module) do
    application = Application.get_application(module)
    anno = create_anno_from_module(module)

    %__MODULE__{
      application: application,
      module: module,
      anno: anno
    }
  end

  @doc """
  Creates a SourceLocation from an application and file path.

  This is useful when you have a file path and know which application
  it belongs to, but don't have module information. The annotation
  will be created with line 1.

  ## Examples

      iex> SourceLocation.from_path(:my_app, "/path/to/file.ex")
      %SourceLocation{application: :my_app, module: nil, anno: anno}

  """
  @spec from_path(Application.app(), String.t()) :: t()
  def from_path(application, path) do
    anno = :erl_anno.set_file(String.to_charlist(path), :erl_anno.new(1))

    %__MODULE__{
      application: application,
      module: nil,
      anno: anno
    }
  end

  with {:module, Spark} <- Code.ensure_loaded(Spark) do
    @doc """
    Creates a SourceLocation from a Spark DSL entity.

    This function is only available when Spark is loaded. It extracts
    the annotation from the entity and determines the application that
    contains the entity's module.

    ## Examples

        iex> SourceLocation.from_spark_entity(
        ...>   My.Ash.Resource,
        ...>   List.first(Ash.Domain.info().attributes())
        ...> )
        %SourceLocation{application: :my_app, module: My.Ash.Resource, anno: anno}

    """
    @spec from_spark_entity(module(), Entity.entity()) :: t()
    def from_spark_entity(module, %{} = entity) do
      application = Application.get_application(module)

      case Entity.anno(entity) do
        nil ->
          create_anno_from_module(module)

        anno ->
          %__MODULE__{
            application: application,
            module: module,
            anno: anno
          }
      end
    end
  end

  @doc """
  Extracts the file path from the source location.

  Returns the file path as a string, or `nil` if no file information
  is available in the annotation.

  ## Parameters

  - `source_location` - The SourceLocation struct
  - `relative_to` - How to format the path:
    - `:absolute` (default) - Return absolute path using `Path.expand/1`
    - `:cwd` - Return path relative to current working directory
    - `:app` - Return path relative to application root (not yet implemented)

  ## Examples

      iex> SourceLocation.file_path(source_location)
      "/absolute/path/to/file.ex"

      iex> SourceLocation.file_path(source_location, :cwd)
      "lib/file.ex"

      iex> SourceLocation.file_path(source_location, :absolute)
      "/absolute/path/to/file.ex"

  """
  @spec file_path(t(), :absolute | :cwd | :app) :: Path.t() | nil
  def file_path(%__MODULE__{anno: anno, application: application}, relative_to \\ :absolute) do
    case :erl_anno.file(anno) do
      :undefined ->
        nil

      file ->
        path = if is_list(file), do: List.to_string(file), else: file

        case relative_to do
          :absolute -> Path.expand(path)
          :cwd -> Path.relative_to_cwd(path)
          :app when application != nil -> Path.relative_to(path, app_path(application))
          :app -> Path.expand(path)
        end
    end
  end

  @doc """
  Extracts the line number from the source location.

  Returns the line number as a positive integer. If no line information
  is available, returns 1 as a sensible default.

  ## Examples

      iex> SourceLocation.line(source_location)
      42

  """
  @spec line(t()) :: pos_integer()
  def line(%__MODULE__{anno: anno}) do
    case :erl_anno.line(anno) do
      line when is_integer(line) and line > 0 -> line
      _ -> 1
    end
  end

  @doc """
  Extracts the column number from the source location.

  Returns the column number as a positive integer, or `nil` if no
  column information is available.

  ## Examples

      iex> SourceLocation.column(source_location)
      15

      iex> SourceLocation.column(source_location_without_column)
      nil

  """
  @spec column(t()) :: pos_integer() | nil
  def column(%__MODULE__{anno: anno}) do
    case :erl_anno.column(anno) do
      :undefined -> nil
      column -> column
    end
  end

  # Private functions

  @spec create_anno_from_module(module()) :: :erl_anno.anno()
  defp create_anno_from_module(module) do
    case get_module_source_file(module) do
      {:ok, source_file} ->
        :erl_anno.set_file(source_file, :erl_anno.new(1))

      :error ->
        # Create a generic annotation with line 1 if we can't get source file
        :erl_anno.new(1)
    end
  end

  @spec get_module_source_file(module()) :: {:ok, charlist()} | :error
  defp get_module_source_file(module) do
    case module.__info__(:compile)[:source] do
      source when is_list(source) -> {:ok, source}
      _ -> :error
    end
  rescue
    _ -> :error
  end

  @spec app_path(Application.app()) :: Path.t()
  defp app_path(app) do
    Application.started_applications()
    |> Enum.any?(&match?({:mix, _description, _version}, &1))
    |> then(fn
      true -> load_mix_app_path(app)
      false -> "/"
    end)
  end

  @spec load_mix_app_path(Application.app()) :: Path.t()
  defp load_mix_app_path(app) do
    if Mix.Project.config()[:app] == app do
      File.cwd!()
    else
      case Mix.Project.deps_paths() do
        %{^app => path} -> Path.expand(path)
        _ -> "/"
      end
    end
  end
end
