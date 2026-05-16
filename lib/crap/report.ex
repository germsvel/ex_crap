defmodule Crap.Report do
  @moduledoc """
  Builds CRAP report rows from complexity and coverage data.
  """

  @doc """
  Joins complexity results with coverage by `{module, function, arity}`.
  """
  def rows(functions, coverage_by_function)
      when is_list(functions) and is_map(coverage_by_function) do
    rows(functions, coverage_by_function, nil)
  end

  @doc """
  Joins complexity results with coverage and normalizes files relative to `root` when provided.
  """
  def rows(functions, coverage_by_function, root)
      when is_list(functions) and is_map(coverage_by_function) and
             (is_binary(root) or is_nil(root)) do
    functions
    |> Enum.map(&normalize_file(&1, root))
    |> Enum.map(&row(&1, coverage_by_function))
  end

  @doc """
  Groups rows that should fail threshold enforcement.
  """
  def failures(rows, max_score) when is_list(rows) and is_number(max_score) do
    %{
      high_scores: Enum.filter(rows, &high_score?(&1, max_score)),
      missing_coverage: Enum.filter(rows, &match?({:missing_coverage, _key}, &1.status)),
      score_errors: Enum.filter(rows, &match?({:error, _reason}, &1.status))
    }
  end

  @doc """
  Renders report rows as a deterministic plain text table.
  """
  def render(rows) when is_list(rows) do
    sorted_rows = Enum.sort_by(rows, &sort_key/1)

    (["File | Module | Function | Complexity | Coverage | CRAP | Status"] ++
       Enum.map(sorted_rows, &render_row/1) ++ [render_summary(rows)])
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  defp row(function, coverage_by_function) do
    key = {function.module, function.function, function.arity}

    function
    |> Map.put(:coverage_percent, nil)
    |> Map.put(:score, nil)
    |> put_score(key, Map.fetch(coverage_by_function, key))
  end

  defp put_score(row, key, :error), do: Map.put(row, :status, {:missing_coverage, key})

  defp put_score(row, _key, {:ok, coverage_percent}) do
    case Crap.score(row.complexity, coverage_percent) do
      {:ok, score} ->
        row
        |> Map.put(:coverage_percent, coverage_percent)
        |> Map.put(:score, score)
        |> Map.put(:status, :scored)

      {:error, reason} ->
        Map.put(row, :status, {:error, reason})
    end
  end

  defp normalize_file(function, nil), do: function

  defp normalize_file(function, root) do
    Map.update!(function, :file, &Path.relative_to(&1, root))
  end

  defp high_score?(%{score: score}, max_score) when is_number(score), do: score > max_score
  defp high_score?(_row, _max_score), do: false

  defp sort_key(row),
    do: {score_sort(row.score), row.file, inspect(row.module), row.function, row.arity}

  defp score_sort(nil), do: {1, 0}
  defp score_sort(score), do: {0, -score}

  defp render_row(row) do
    [
      row.file,
      inspect(row.module),
      "#{row.function}/#{row.arity}",
      to_string(row.complexity),
      format_coverage(row.coverage_percent),
      format_score(row.score),
      format_status(row.status)
    ]
    |> Enum.join(" | ")
  end

  defp render_summary(rows) do
    files = rows |> Enum.map(& &1.file) |> Enum.uniq() |> length()
    scored = Enum.count(rows, &(&1.status == :scored))
    missing = Enum.count(rows, &match?({:missing_coverage, _key}, &1.status))

    worst_score =
      rows |> Enum.map(& &1.score) |> Enum.reject(&is_nil/1) |> Enum.max(fn -> nil end)

    "Summary: files=#{files} functions=#{length(rows)} scored=#{scored} " <>
      "missing_coverage=#{missing} worst_score=#{format_score(worst_score)}"
  end

  defp format_coverage(nil), do: "missing"
  defp format_coverage(percent), do: "#{format_number(percent)}%"

  defp format_score(nil), do: "-"
  defp format_score(score), do: format_number(score)

  defp format_number(number), do: :erlang.float_to_binary(number * 1.0, decimals: 2)

  defp format_status(:scored), do: "scored"
  defp format_status({:missing_coverage, _key}), do: "missing coverage"
  defp format_status({:error, reason}), do: "error: #{reason}"
end
