defmodule Clarity.Phoenix.Pipeline do
  @moduledoc """
  Reads the plugs a Phoenix endpoint, or a router's pipelines, run in order,
  from their compiled code, and says what the well-known ones do.

  Phoenix compiles an endpoint's `plug`s, and each router `pipeline`'s, into
  nested calls and keeps no list of them, so they're read from the module's
  debug info. That's what actually runs, after compile-time conditions such
  as `if code_reloading?`. A build without debug info, such as a release
  that strips it, gives `:error`.
  """

  alias Clarity.Components.OverviewComponents
  alias Phoenix.Ecto.CheckRepoStatus
  alias Phoenix.LiveDashboard.RequestLogger

  @typedoc """
  A plug: a module's `call/2`, or a function, with the options it's given
  and the guard it runs under, if any (see `runs?/2`).

  Its options are as written when Phoenix's `:plug_init_mode` is `:runtime`
  (`init: :runtime`), or as its `init/1` returned them when it's `:compile`.
  Options that aren't plain data, such as captured functions, are kept as
  `{:code, source}`.
  """
  @type plug() :: %{
          kind: :module | :function,
          module: module(),
          function: atom(),
          opts: term(),
          init: :compile | :runtime,
          guard: Macro.t() | nil
        }

  # What the plugs Phoenix apps commonly use do, in a line.
  @about %{
    Phoenix.CodeReloader => "Recompiles changed code before each request",
    CheckRepoStatus => "Checks the database is created and migrated",
    RequestLogger => "Streams a request's logs to LiveDashboard",
    Phoenix.LiveReloader => "Reloads the browser when files change",
    Plug.Head => "Answers HEAD requests as GETs, without the body",
    Plug.Logger => "Logs each request",
    Plug.MethodOverride => "Lets a POST form act as a PUT, PATCH or DELETE, by its _method field",
    Plug.Parsers => "Parses request bodies into params",
    Plug.RequestId => "Gives each request an ID, sent back in a response header",
    Plug.SSL => "Redirects to HTTPS, and tells browsers to stay there",
    Plug.Session => "Keeps a session for each visitor",
    Plug.Static => "Serves static files, before anything else runs",
    Plug.Telemetry => "Times each request, for telemetry and logs",
    {Phoenix.Controller, :accepts} => "Accepts only these formats, or responds 406",
    {Phoenix.Controller, :fetch_flash} => "Loads flash messages",
    {Phoenix.Controller, :protect_from_forgery} => "Rejects forms without a valid CSRF token",
    {Phoenix.Controller, :put_root_layout} => "Sets the root layout",
    {Phoenix.Controller, :put_secure_browser_headers} => "Sets browser security headers",
    {Phoenix.LiveView.Router, :fetch_live_flash} => "Loads flash messages, for LiveViews too",
    {Plug.Conn, :fetch_cookies} => "Reads the request's cookies",
    {Plug.Conn, :fetch_query_params} => "Parses the query string into params",
    {Plug.Conn, :fetch_session} => "Loads the session"
  }

  # Plugs that only development builds run.
  @dev [
    Phoenix.CodeReloader,
    CheckRepoStatus,
    RequestLogger,
    Phoenix.LiveReloader
  ]

  @doc """
  Returns the plugs a `Plug.Builder` module, such as an endpoint, runs, in
  order.

  An endpoint's first is its `socket_dispatch` function, which hands socket
  connections to the handlers declared with `Phoenix.Endpoint.socket/3`.

  ## Examples

      iex> Clarity.Phoenix.Pipeline.plugs(Enum)
      :error

  """
  @spec plugs(module()) :: {:ok, [plug()]} | :error
  def plugs(module) do
    with {:ok, definitions} <- definitions(module),
         {_name, _kind, _meta, [{_clause_meta, _args, _guards, body}]} <-
           List.keyfind(definitions, {:plug_builder_call, 2}, 0) do
      {:ok, chain(body, module)}
    else
      _missing -> :error
    end
  end

  @doc """
  Returns the plugs a Phoenix controller runs before its action, in order,
  with the guard each runs under, such as `action in [:create]`. Those every
  controller runs, to set its layout and view, are left out.
  """
  @spec controller(module()) :: {:ok, [plug()]} | :error
  def controller(controller) do
    with {:ok, definitions} <- definitions(controller),
         {_name, _kind, _meta, [{_clause_meta, _args, _guards, body}]} <-
           List.keyfind(definitions, {:phoenix_controller_pipeline, 2}, 0) do
      {:ok, body |> chain(controller) |> Enum.reject(&implicit?/1)}
    else
      _missing -> :error
    end
  end

  @doc """
  Returns a router's pipelines, in the order it defines them, with the plugs
  each runs.
  """
  @spec pipelines(module()) :: {:ok, [{atom(), [plug()]}]} | :error
  def pipelines(router) do
    with {:ok, definitions} <- definitions(router) do
      pipelines =
        for {{name, 2}, :def, meta, [{_clause_meta, _args, _guards, body}]} <- definitions,
            pipeline?(name, body) do
          {meta[:line], name, chain(body, router)}
        end

      {:ok, pipelines |> Enum.sort() |> Enum.map(fn {_line, name, plugs} -> {name, plugs} end)}
    end
  end

  @doc """
  Returns a plug's name as it's written in a `plug` call: its module, or
  its function's name.

  ## Examples

      iex> Clarity.Phoenix.Pipeline.name(%{kind: :module, module: Plug.Head, function: :call})
      "Plug.Head"

      iex> Clarity.Phoenix.Pipeline.name(%{
      ...>   kind: :function,
      ...>   module: Plug.Conn,
      ...>   function: :fetch_session
      ...> })
      "fetch_session"

  """
  @spec name(plug() | map()) :: String.t()
  def name(%{kind: :module, module: module}), do: inspect(module)
  def name(%{kind: :function, function: function}), do: Atom.to_string(function)

  @doc """
  Says what a plug does in a line: for the plugs Phoenix apps commonly use,
  from what Clarity knows, and for others from the first sentence of their
  docs, if any.

  ## Examples

      iex> Clarity.Phoenix.Pipeline.about(%{kind: :module, module: Plug.Head, function: :call})
      "Answers HEAD requests as GETs, without the body"

  """
  @spec about(plug() | map()) :: String.t() | nil
  def about(%{kind: :module, module: module}),
    do: Map.get_lazy(@about, module, fn -> module_doc(module) end)

  def about(%{kind: :function, module: module, function: function}),
    do: Map.get_lazy(@about, {module, function}, fn -> function_doc(module, function) end)

  @doc """
  Returns whether a controller's plug runs for an action, by its guard:
  `true` when it has none, and `:unknown` when its guard needs more than the
  action, such as the conn.

  The guard isn't run as code: it's worked out here, by the operators and
  functions Erlang allows in guards, and nothing else.
  """
  @spec runs?(plug(), atom()) :: boolean() | :unknown
  def runs?(%{guard: nil}, _action), do: true

  def runs?(%{guard: guard}, action) do
    case evaluate(guard, action) do
      {:ok, value} -> value == true
      :unknown -> :unknown
    end
  end

  @doc "Returns whether only development builds run a plug, such as a code reloader."
  @spec dev?(plug() | map()) :: boolean()
  def dev?(%{kind: :module, module: module}), do: module in @dev
  def dev?(_plug), do: false

  @doc """
  Returns the options worth showing beside a plug, briefly: which parsers
  `Plug.Parsers` uses, `Plug.Session`'s store and cookie, where `Plug.Static`
  serves from, and a function plug's list of names, such as the formats
  `accepts` takes.

  Other options aren't shown, as they may hold secrets, such as a session's
  signing salt.

  ## Examples

      iex> Clarity.Phoenix.Pipeline.options(%{
      ...>   kind: :module,
      ...>   module: Plug.Parsers,
      ...>   init: :runtime,
      ...>   opts: [parsers: [:urlencoded, :json], pass: ["*/*"]]
      ...> })
      ["urlencoded", "json"]

      iex> Clarity.Phoenix.Pipeline.options(%{kind: :function, init: :compile, opts: ["html"]})
      ["html"]

  """
  @spec options(plug() | map()) :: [String.t()]
  def options(%{kind: :module, module: Plug.Parsers, init: :runtime, opts: opts}),
    do: opts |> keyword(:parsers) |> List.wrap() |> Enum.map(&parser_name/1)

  def options(%{kind: :module, module: Plug.Parsers, opts: opts})
      when is_tuple(opts) and is_list(elem(opts, 0)),
      do: for({parser, _opts} <- elem(opts, 0), do: parser_name(parser))

  def options(%{kind: :module, module: Plug.Session, opts: opts}) do
    store = keyword(opts, :store)
    key = keyword(opts, :key)

    Enum.filter(
      [store && "#{parser_name(store)} store", is_binary(key) && "key #{key}"],
      &is_binary/1
    )
  end

  def options(%{kind: :module, module: Plug.Static, opts: opts}) do
    at = keyword(opts, :at)
    from = keyword(opts, :from)

    Enum.filter([at && "at #{static_at(at)}", from && "from #{static_from(from)}"], &is_binary/1)
  end

  def options(%{kind: :function, opts: opts}) when is_list(opts) and opts != [] do
    if Enum.all?(opts, &(is_binary(&1) or (is_atom(&1) and not is_boolean(&1)))),
      do: Enum.map(opts, &to_string/1),
      else: []
  end

  def options(_plug), do: []

  @spec definitions(module()) :: {:ok, list()} | :error
  defp definitions(module) do
    with path when is_list(path) <- :code.which(module),
         {:ok, {^module, [debug_info: {:debug_info_v1, backend, data}]}} <-
           :beam_lib.chunks(path, [:debug_info]),
         {:ok, %{definitions: definitions}} <- backend.debug_info(:elixir_v1, module, data, []) do
      {:ok, definitions}
    else
      _missing -> :error
    end
  end

  @spec implicit?(plug()) :: boolean()
  defp implicit?(%{kind: :function, module: Phoenix.Controller, function: function})
       when function in [:put_new_layout, :put_new_view], do: true

  defp implicit?(%{kind: :function, function: :action}), do: true
  defp implicit?(_plug), do: false

  # A pipeline is a public function of the router that runs its plugs
  # inside a `try`, rescuing their wrapped errors.
  @spec pipeline?(atom(), Macro.t()) :: boolean()
  defp pipeline?(name, {:try, _meta, [[{:do, _body}, {:rescue, _rescue} | _rest]]}),
    do: not String.starts_with?(Atom.to_string(name), "__")

  defp pipeline?(_name, _body), do: false

  # Plug.Builder compiles plugs into nested cases: each calls a plug, and
  # carries on in its clause for a conn that hasn't halted.
  @spec chain(Macro.t(), module()) :: [plug()]
  defp chain({:try, _meta, [[{:do, body} | _rest]]}, owner), do: chain(body, owner)

  defp chain({:__block__, _meta, [_ | _] = exprs}, owner),
    do: exprs |> List.last() |> chain(owner)

  defp chain({:case, _meta, [call, [do: clauses]]}, owner) do
    case plug(call, owner) do
      nil -> []
      plug -> [plug | clauses |> carry_on() |> chain(owner)]
    end
  end

  defp chain(_conn, _owner), do: []

  @spec carry_on([Macro.t()]) :: Macro.t() | nil
  defp carry_on(clauses) do
    Enum.find_value(clauses, fn
      {:->, _meta, [[{:=, _, [{:%, _, [Plug.Conn, {:%{}, _, []}]}, _conn]}], next]} -> next
      _clause -> nil
    end)
  end

  @spec plug(Macro.t(), module()) :: plug() | nil
  defp plug(
         {:case, _meta, [true, [do: [{:->, _, [[{:when, _, [true, guard]}], call]} | _]]]},
         owner
       ) do
    with %{} = plug <- plug(call, owner), do: %{plug | guard: guard}
  end

  defp plug({{:., _, [module, :call]}, _meta, [_conn, opts]}, _owner) when is_atom(module),
    do: new(:module, module, :call, opts)

  defp plug({{:., _, [module, function]}, _meta, [_conn, opts]}, _owner) when is_atom(module),
    do: new(:function, module, function, opts)

  defp plug({function, _meta, [_conn, opts]}, owner) when is_atom(function),
    do: new(:function, owner, function, opts)

  defp plug(_call, _owner), do: nil

  @spec new(:module | :function, module(), atom(), Macro.t()) :: plug()
  defp new(kind, module, function, {{:., _, [module, :init]}, _meta, [opts]}),
    do: %{
      kind: kind,
      module: module,
      function: function,
      opts: term(opts),
      init: :runtime,
      guard: nil
    }

  defp new(kind, module, function, opts),
    do: %{
      kind: kind,
      module: module,
      function: function,
      opts: term(opts),
      init: :compile,
      guard: nil
    }

  # Works out a guard's value for an action, as Erlang would: a guard that
  # raises fails. Its `and` and `or` are short-circuiting in Erlang, but
  # guards have no side effects, so working out both sides is the same.
  @spec evaluate(Macro.t(), atom()) :: {:ok, term()} | :unknown
  defp evaluate({:action, _meta, context}, action) when is_atom(context), do: {:ok, action}

  defp evaluate({{:., _, [:erlang, operator]}, _meta, [left, right]}, action)
       when operator in [:andalso, :orelse] do
    with {:ok, left} <- evaluate(left, action),
         {:ok, right} <- evaluate(right, action) do
      case operator do
        :andalso -> {:ok, left == true and right == true}
        :orelse -> {:ok, left == true or right == true}
      end
    end
  end

  defp evaluate({{:., _, [:erlang, function]}, _meta, args}, action) when is_list(args) do
    with true <- guard_function?(function, length(args)),
         {:ok, values} <- evaluate_all(args, action) do
      {:ok, apply(:erlang, function, values)}
    else
      _other -> :unknown
    end
  rescue
    ArgumentError -> {:ok, false}
  end

  defp evaluate({:{}, _meta, items}, action) do
    with {:ok, values} <- evaluate_all(items, action), do: {:ok, List.to_tuple(values)}
  end

  defp evaluate({left, right}, action) do
    with {:ok, [left, right]} <- evaluate_all([left, right], action), do: {:ok, {left, right}}
  end

  defp evaluate(list, action) when is_list(list), do: evaluate_all(list, action)

  defp evaluate(literal, _action)
       when is_atom(literal) or is_number(literal) or is_binary(literal), do: {:ok, literal}

  defp evaluate(_other, _action), do: :unknown

  @spec evaluate_all([Macro.t()], atom()) :: {:ok, [term()]} | :unknown
  defp evaluate_all(asts, action) do
    asts
    |> Enum.reduce_while({:ok, []}, fn ast, {:ok, values} ->
      case evaluate(ast, action) do
        {:ok, value} -> {:cont, {:ok, [value | values]}}
        :unknown -> {:halt, :unknown}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      :unknown -> :unknown
    end
  end

  @spec guard_function?(atom(), arity()) :: boolean()
  defp guard_function?(function, arity) do
    :erl_internal.guard_bif(function, arity) or :erl_internal.comp_op(function, arity) or
      :erl_internal.arith_op(function, arity) or :erl_internal.bool_op(function, arity) or
      :erl_internal.type_test(function, arity)
  end

  # Turns escaped options back into terms, without evaluating any code.
  @spec term(Macro.t()) :: term()
  defp term({:{}, _meta, items}), do: items |> Enum.map(&term/1) |> List.to_tuple()

  defp term({:%{}, _meta, pairs}),
    do: Map.new(pairs, fn {key, value} -> {term(key), term(value)} end)

  defp term({left, right}), do: {term(left), term(right)}
  defp term(list) when is_list(list), do: Enum.map(list, &term/1)

  defp term(literal) when is_atom(literal) or is_number(literal) or is_binary(literal),
    do: literal

  defp term(code), do: {:code, Macro.to_string(code)}

  @spec keyword(term(), atom()) :: term()
  defp keyword(%{} = opts, key), do: Map.get(opts, key)

  defp keyword(opts, key) when is_list(opts) do
    if Keyword.keyword?(opts), do: Keyword.get(opts, key)
  end

  defp keyword(_opts, _key), do: nil

  # A parser or session store, as it's named in options: `:json` for
  # `Plug.Parsers.JSON`.
  @spec parser_name(term()) :: String.t()
  defp parser_name(module) when is_atom(module) do
    case Atom.to_string(module) do
      "Elixir." <> _module -> module |> Module.split() |> List.last() |> String.downcase()
      name -> name
    end
  end

  defp parser_name(other), do: inspect(other)

  @spec static_at(term()) :: String.t()
  defp static_at(segments) when is_list(segments), do: "/" <> Enum.join(segments, "/")
  defp static_at(at), do: to_string(at)

  @spec static_from(term()) :: String.t()
  defp static_from({app, path}) when is_atom(app), do: "#{path} of #{inspect(app)}"
  defp static_from(app) when is_atom(app), do: "priv/static of #{inspect(app)}"
  defp static_from(path) when is_binary(path), do: path
  defp static_from(from), do: inspect(from)

  @spec module_doc(module()) :: String.t() | nil
  defp module_doc(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _anno, _language, _format, %{"en" => doc}, _meta, _docs} -> first_line(doc)
      _none -> nil
    end
  end

  @spec function_doc(module(), atom()) :: String.t() | nil
  defp function_doc(module, function) do
    with {:docs_v1, _anno, _language, _format, _moduledoc, _meta, docs} <- Code.fetch_docs(module),
         {_key, _anno, _signature, %{"en" => doc}, _doc_meta} <-
           List.keyfind(docs, {:function, function, 2}, 0) do
      first_line(doc)
    else
      _none -> nil
    end
  end

  @spec first_line(String.t()) :: String.t() | nil
  defp first_line(doc) do
    case doc |> OverviewComponents.first_sentence() |> String.split() do
      [] -> nil
      words -> words |> Enum.join(" ") |> String.trim_trailing(".")
    end
  end
end
