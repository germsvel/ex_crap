defmodule Crap.Complexity do
  @moduledoc """
  Parses Elixir source and returns sprint-local cyclomatic complexity results for
  supported executable containers, including modules and protocol implementations.

  Source is parsed with `Code.string_to_quoted/1`; analyzed code is not compiled or
  evaluated. Each result includes `module`, `function`, `arity`, `line`, and
  `complexity`.

  Current decision-point rules:

  * Each discovered `def`, `defp`, `defmacro`, or `defmacrop` starts with base complexity `1`.
  * Each `if` and `unless` adds `1`.
  * Each `case` branch adds `1`.
  * Each `cond` clause adds `1`.
  * Each `with` generator and `else` branch adds `1`.
  * `try` adds `1`; each `else`, `rescue`, and `catch` clause adds `1`.
  * Each `for` generator and filter adds `1`.
  * Each `receive` branch adds `1`; an `after` timeout branch adds `1`.
  * Boolean `and`, `or`, `&&`, and `||` operators add `1` each.
  * Boolean operators in function guards add `1` each.
  * Multiple clauses for the same `{module, function, arity}` are aggregated by
    summing one path per clause plus each clause's guard/body decisions.
  """

  @definition_kinds [:def, :defp, :defmacro, :defmacrop]

  @doc """
  Returns per-function complexity results for an Elixir source string.

  Invalid source returns `{:error, :invalid_source}`. Valid source with no
  analyzable function or macro bodies returns `{:ok, []}`.
  """
  def from_string(source) when is_binary(source) do
    case Code.string_to_quoted(source) do
      {:ok, quoted} ->
        if malformed_executable_container?(quoted) do
          {:error, :invalid_source}
        else
          {:ok, quoted |> functions(nil) |> aggregate_clauses()}
        end

      {:error, _reason} ->
        {:error, :invalid_source}
    end
  end

  def from_string(_source), do: {:error, :invalid_source}

  @doc """
  Reads one Elixir source file and returns per-function complexity results.

  This helper analyzes a single caller-provided file only. Project-wide scanning
  remains deferred.
  """
  def from_file(path) when is_binary(path) do
    case File.read(path) do
      {:ok, source} -> from_string(source)
      {:error, reason} -> {:error, reason}
    end
  end

  def from_file(_path), do: {:error, :invalid_path}

  defp functions(quoted, module), do: functions(quoted, module, MapSet.new(), MapSet.new())

  defp functions(
         {:defmodule, _meta, [module_ast, [do: body]]},
         current_module,
         _local_protocols,
         _local_modules
       ) do
    module = module_name(module_ast, current_module)

    functions(
      body,
      module,
      body |> local_protocol_modules(module) |> MapSet.new(),
      body |> local_module_declarations(module) |> MapSet.new()
    )
  end

  defp functions({:defimpl, _meta, args}, current_module, local_protocols, local_modules) do
    case defimpl_parts(args, current_module) do
      {:ok, protocol_ast, for_ast, body} ->
        protocol_ast
        |> defimpl_module_names(for_ast, current_module, local_protocols, local_modules)
        |> Enum.flat_map(&functions(body, &1))

      :error ->
        []
    end
  end

  defp functions({kind, meta, [head, [do: body]]}, module, _local_protocols, _local_modules)
       when kind in @definition_kinds do
    {function, arity, guards} = function_name_arity_and_guards(head)

    [
      %{
        module: module,
        function: function,
        arity: arity,
        line: meta[:line],
        complexity: 1 + decision_count(guards) + decision_count(body)
      }
    ]
  end

  defp functions({:__block__, _meta, expressions}, module, local_protocols, local_modules) do
    Enum.flat_map(expressions, &functions(&1, module, local_protocols, local_modules))
  end

  defp functions(list, module, local_protocols, local_modules) when is_list(list) do
    Enum.flat_map(list, &functions(&1, module, local_protocols, local_modules))
  end

  defp functions({branch, _meta, args}, module, local_protocols, local_modules)
       when branch in [:if, :unless] do
    case List.last(args) do
      branches when is_list(branches) ->
        Enum.flat_map(
          Keyword.values(branches),
          &functions(&1, module, local_protocols, local_modules)
        )

      _other ->
        []
    end
  end

  defp functions(_quoted, _module, _local_protocols, _local_modules), do: []

  defp malformed_executable_container?(quoted),
    do: malformed_executable_container?(quoted, nil, false)

  defp malformed_executable_container?(
         {:defmodule, _meta, [module_ast, [do: body]]},
         current_module,
         _in_executable?
       ) do
    not module_alias?(module_ast) ||
      malformed_executable_container?(body, module_name(module_ast, current_module), true)
  end

  defp malformed_executable_container?(
         {:defmodule, _meta, _args},
         _current_module,
         _in_executable?
       ),
       do: true

  defp malformed_executable_container?(
         {:defimpl, _meta, args},
         current_module,
         _in_executable?
       ) do
    case defimpl_parts(args, current_module) do
      {:ok, protocol_ast, for_ast, body} ->
        not defimpl_name_ast?(protocol_ast, for_ast) ||
          malformed_executable_container?(body, current_module, true)

      :error ->
        true
    end
  end

  defp malformed_executable_container?({kind, _meta, [_head]}, _current_module, true)
       when kind in @definition_kinds do
    true
  end

  defp malformed_executable_container?({kind, _meta, [_head, [do: body]]}, current_module, true)
       when kind in @definition_kinds do
    malformed_executable_container?(body, current_module, false)
  end

  defp malformed_executable_container?({branch, _meta, args}, current_module, in_executable?)
       when branch in [:if, :unless] do
    case List.last(args) do
      branches when is_list(branches) ->
        branches
        |> Keyword.values()
        |> Enum.any?(&malformed_executable_container?(&1, current_module, in_executable?))

      _other ->
        false
    end
  end

  defp malformed_executable_container?(
         {:__block__, _meta, expressions},
         current_module,
         in_executable?
       ) do
    Enum.any?(expressions, &malformed_executable_container?(&1, current_module, in_executable?))
  end

  defp malformed_executable_container?(list, current_module, in_executable?) when is_list(list) do
    Enum.any?(list, &malformed_executable_container?(&1, current_module, in_executable?))
  end

  defp malformed_executable_container?(_quoted, _current_module, _in_executable?), do: false

  defp module_alias?({:__aliases__, _meta, parts}) when is_list(parts), do: true
  defp module_alias?(_ast), do: false

  defp local_protocol_modules({:__block__, _meta, expressions}, current_module) do
    Enum.flat_map(expressions, &local_protocol_modules(&1, current_module))
  end

  defp local_protocol_modules({:defprotocol, _meta, [protocol_ast, [do: _body]]}, current_module)
       when not is_nil(current_module) do
    if module_alias?(protocol_ast), do: [module_name(protocol_ast, current_module)], else: []
  end

  defp local_protocol_modules(_quoted, _current_module), do: []

  defp local_module_declarations({:__block__, _meta, expressions}, current_module) do
    Enum.flat_map(expressions, &local_module_declarations(&1, current_module))
  end

  defp local_module_declarations({:defmodule, _meta, [module_ast, [do: _body]]}, current_module)
       when not is_nil(current_module) do
    if module_alias?(module_ast), do: [module_name(module_ast, current_module)], else: []
  end

  defp local_module_declarations(_quoted, _current_module), do: []

  defp defimpl_parts([protocol_ast, opts, [do: body]], current_module)
       when is_list(opts) do
    with {:ok, for_ast} <- defimpl_for_ast(opts, current_module, body) do
      {:ok, protocol_ast, for_ast, body}
    end
  end

  defp defimpl_parts([protocol_ast, [do: body]], current_module)
       when not is_nil(current_module) do
    {:ok, protocol_ast, current_module, body}
  end

  defp defimpl_parts([protocol_ast, opts], _current_module)
       when is_list(opts) do
    with {:ok, for_ast} <- Keyword.fetch(opts, :for),
         {:ok, body} <- Keyword.fetch(opts, :do) do
      {:ok, protocol_ast, for_ast, body}
    else
      :error -> :error
    end
  end

  defp defimpl_parts(_args, _current_module), do: :error

  defp defimpl_for_ast(opts, current_module, _body) do
    case Keyword.fetch(opts, :for) do
      {:ok, for_ast} -> {:ok, for_ast}
      :error when not is_nil(current_module) -> {:ok, current_module}
      :error -> :error
    end
  end

  defp defimpl_name_ast?(protocol_ast, for_ast) when is_list(for_ast) do
    module_alias?(protocol_ast) and Enum.all?(for_ast, &defimpl_target_ast?/1)
  end

  defp defimpl_name_ast?(protocol_ast, for_ast),
    do: module_alias?(protocol_ast) and defimpl_target_ast?(for_ast)

  defp defimpl_target_ast?(for_ast) when is_atom(for_ast), do: true
  defp defimpl_target_ast?(for_ast), do: module_alias?(for_ast)

  defp aggregate_clauses(functions) do
    functions
    |> Enum.group_by(&{&1.module, &1.function, &1.arity})
    |> Enum.map(fn {_key, clauses} ->
      first = Enum.min_by(clauses, &(&1.line || 0))

      complexity = clauses |> Enum.map(& &1.complexity) |> Enum.sum()

      %{first | complexity: complexity}
    end)
    |> Enum.sort_by(&{inspect(&1.module), &1.line || 0, &1.function, &1.arity})
  end

  defp module_name({:__aliases__, _meta, parts}, nil), do: Module.concat(parts)
  defp module_name({:__aliases__, _meta, parts}, parent), do: Module.concat([parent | parts])

  defp protocol_module_name(protocol_ast, current_module, local_protocols)
       when not is_nil(current_module) do
    local_protocol = module_name(protocol_ast, current_module)

    if MapSet.member?(local_protocols, local_protocol) do
      local_protocol
    else
      module_name(protocol_ast, nil)
    end
  end

  defp protocol_module_name(protocol_ast, _current_module, _local_protocols),
    do: module_name(protocol_ast, nil)

  defp defimpl_module_names(protocol_ast, for_ast, current_module, local_protocols, local_modules)
       when is_list(for_ast) do
    Enum.map(
      for_ast,
      &defimpl_module_name(protocol_ast, &1, current_module, local_protocols, local_modules)
    )
  end

  defp defimpl_module_names(protocol_ast, for_ast, current_module, local_protocols, local_modules) do
    [defimpl_module_name(protocol_ast, for_ast, current_module, local_protocols, local_modules)]
  end

  defp defimpl_module_name(
         protocol_ast,
         for_module,
         current_module,
         local_protocols,
         _local_modules
       )
       when is_atom(for_module) do
    Module.concat([
      protocol_module_name(protocol_ast, current_module, local_protocols),
      for_module
    ])
  end

  defp defimpl_module_name(protocol_ast, for_ast, current_module, local_protocols, local_modules) do
    Module.concat([
      protocol_module_name(protocol_ast, current_module, local_protocols),
      target_module_name(for_ast, current_module, local_modules)
    ])
  end

  defp target_module_name(for_ast, nil, _local_modules), do: module_name(for_ast, nil)

  defp target_module_name(for_ast, current_module, local_modules) do
    local_module = module_name(for_ast, current_module)

    if MapSet.member?(local_modules, local_module) do
      local_module
    else
      module_name(for_ast, nil)
    end
  end

  defp function_name_arity_and_guards({:when, _meta, [head | guards]}) do
    {name, arity, existing_guards} = function_name_arity_and_guards(head)
    {name, arity, existing_guards ++ guards}
  end

  defp function_name_arity_and_guards({name, _meta, nil}) when is_atom(name), do: {name, 0, []}

  defp function_name_arity_and_guards({name, _meta, args}) when is_atom(name),
    do: {name, length(args), []}

  defp decision_count(list) when is_list(list),
    do: Enum.reduce(list, 0, &(&2 + decision_count(&1)))

  defp decision_count({:->, _meta, [patterns, body]}),
    do: decision_count(patterns) + decision_count(body)

  defp decision_count({operator, _meta, args}) when operator in [:and, :or, :&&, :||] do
    1 + decision_count(args)
  end

  defp decision_count({branch, _meta, args}) when branch in [:if, :unless] do
    1 + decision_count(args)
  end

  defp decision_count({branch, _meta, args}) when branch in [:case, :cond] do
    branch_count(args) + decision_count(args)
  end

  defp decision_count({:with, _meta, args}) do
    generator_count(args) + arrow_count(keyword_value(args, :else)) + decision_count(args)
  end

  defp decision_count({:<-, _meta, args}) do
    decision_count(args)
  end

  defp decision_count({:try, _meta, args}) do
    1 + arrow_count(keyword_value(args, :else)) + arrow_count(keyword_value(args, :rescue)) +
      arrow_count(keyword_value(args, :catch)) + decision_count(args)
  end

  defp decision_count({:for, _meta, args}) do
    comprehension_qualifier_count(args) + decision_count(args)
  end

  defp decision_count({:receive, _meta, args}) do
    branch_count(args) + receive_after_count(args) + decision_count(args)
  end

  defp decision_count({:defmodule, _meta, _args}), do: 0
  defp decision_count({_name, _meta, args}) when is_list(args), do: decision_count(args)
  defp decision_count({_left, right}), do: decision_count(right)
  defp decision_count(_quoted), do: 0

  defp branch_count(args), do: args |> keyword_value(:do) |> arrow_count()

  defp keyword_value(args, key) do
    args
    |> Enum.reverse()
    |> Enum.find(&(Keyword.keyword?(&1) and Keyword.has_key?(&1, key)))
    |> case do
      nil -> nil
      keyword -> Keyword.get(keyword, key)
    end
  end

  defp arrow_count(clauses) when is_list(clauses),
    do: Enum.count(clauses, &match?({:->, _meta, _clause}, &1))

  defp arrow_count({:__block__, _meta, clauses}), do: arrow_count(clauses)
  defp arrow_count({:->, _meta, _clause}), do: 1
  defp arrow_count(_other), do: 0

  defp generator_count(args), do: Enum.count(args, &match?({:<-, _meta, _args}, &1))

  defp comprehension_qualifier_count(args) do
    Enum.count(args, fn
      {:<-, _meta, _args} -> true
      keyword when is_list(keyword) -> false
      _filter -> true
    end)
  end

  defp receive_after_count(args), do: if(keyword_value(args, :after), do: 1, else: 0)
end
