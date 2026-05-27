defmodule Crap.Complexity do
  @moduledoc """
  Parses Elixir source and returns sprint-local cyclomatic complexity results.

  Source is parsed with `Code.string_to_quoted/1`; analyzed code is not compiled or
  evaluated. Each result includes `module`, `function`, `arity`, `line`, and
  `complexity`.

  Current decision-point rules:

  * Each discovered `def` or `defp` starts with base complexity `1`.
  * Each `if` and `unless` adds `1`.
  * Each `case` branch adds `1`.
  * Each `cond` clause adds `1`.
  * Boolean `and` and `or` operators in function bodies add `1` each.
  * Multiple clauses for the same `{module, function, arity}` are aggregated by
    keeping the maximum clause complexity and earliest line number.
  """

  @doc """
  Returns per-function complexity results for an Elixir source string.

  Invalid or unsupported source returns `{:error, :invalid_source}`.
  """
  def from_string(source) when is_binary(source) do
    case Code.string_to_quoted(source) do
      {:ok, quoted} ->
        case functions(quoted, nil) do
          [] -> {:error, :invalid_source}
          functions -> {:ok, aggregate_clauses(functions)}
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

  defp functions({:defmodule, _meta, [module_ast, [do: body]]}, current_module) do
    module = module_name(module_ast, current_module)
    functions(body, module)
  end

  defp functions({kind, meta, [head, [do: body]]}, module) when kind in [:def, :defp] do
    {function, arity} = function_name_and_arity(head)

    [
      %{
        module: module,
        function: function,
        arity: arity,
        line: meta[:line],
        complexity: 1 + decision_count(body)
      }
    ]
  end

  defp functions({:__block__, _meta, expressions}, module) do
    Enum.flat_map(expressions, &functions(&1, module))
  end

  defp functions(list, module) when is_list(list) do
    Enum.flat_map(list, &functions(&1, module))
  end

  defp functions(_quoted, _module), do: []

  defp aggregate_clauses(functions) do
    functions
    |> Enum.group_by(&{&1.module, &1.function, &1.arity})
    |> Enum.map(fn {_key, clauses} ->
      first = Enum.min_by(clauses, &(&1.line || 0))
      max_complexity = clauses |> Enum.map(& &1.complexity) |> Enum.max()
      %{first | complexity: max_complexity}
    end)
    |> Enum.sort_by(&{inspect(&1.module), &1.line || 0, &1.function, &1.arity})
  end

  defp module_name({:__aliases__, _meta, parts}, nil), do: Module.concat(parts)
  defp module_name({:__aliases__, _meta, parts}, parent), do: Module.concat([parent | parts])

  defp function_name_and_arity({:when, _meta, [head | _guards]}),
    do: function_name_and_arity(head)

  defp function_name_and_arity({name, _meta, nil}) when is_atom(name), do: {name, 0}
  defp function_name_and_arity({name, _meta, args}) when is_atom(name), do: {name, length(args)}

  defp decision_count(list) when is_list(list),
    do: Enum.reduce(list, 0, &(&2 + decision_count(&1)))

  defp decision_count({:->, _meta, [_patterns, body]}), do: decision_count(body)

  defp decision_count({operator, _meta, args}) when operator in [:and, :or] do
    1 + decision_count(args)
  end

  defp decision_count({branch, _meta, args}) when branch in [:if, :unless] do
    1 + decision_count(args)
  end

  defp decision_count({branch, _meta, args}) when branch in [:case, :cond] do
    branch_count(args) + decision_count(args)
  end

  defp decision_count({_name, _meta, args}) when is_list(args), do: decision_count(args)
  defp decision_count({_left, right}), do: decision_count(right)
  defp decision_count(_quoted), do: 0

  defp branch_count(args) do
    args
    |> Enum.find(&Keyword.keyword?/1)
    |> case do
      nil -> nil
      keyword -> Keyword.get(keyword, :do)
    end
    |> case do
      clauses when is_list(clauses) -> Enum.count(clauses, &match?({:->, _meta, _clause}, &1))
      {:__block__, _meta, clauses} -> Enum.count(clauses, &match?({:->, _meta, _clause}, &1))
      {:->, _meta, _clause} -> 1
      _other -> 0
    end
  end
end
