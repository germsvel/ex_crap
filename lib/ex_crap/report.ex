defmodule ExCrap.Report do
  @moduledoc false

  use Boundary, deps: [ExCrap.Score]

  # Builds CRAP report rows by combining complexity results with coverage data.

  alias ExCrap.Score

  @doc false
  def rows(functions, coverage_by_function)
      when is_list(functions) and is_map(coverage_by_function) do
    rows(functions, coverage_by_function, nil)
  end

  @doc false
  def rows(functions, coverage_by_function, root)
      when is_list(functions) and is_map(coverage_by_function) and
             (is_binary(root) or is_nil(root)) do
    functions
    |> Enum.map(&normalize_file(&1, root))
    |> Enum.map(&row(&1, coverage_by_function))
  end

  @doc false
  def failures(rows, max_score) when is_list(rows) and is_number(max_score) do
    %{
      high_scores: Enum.filter(rows, &high_score?(&1, max_score)),
      score_errors: Enum.filter(rows, &match?({:error, _reason}, &1.status))
    }
  end

  @doc false
  def render(rows, opts \\ []) when is_list(rows) and is_list(opts) do
    sorted_rows = Enum.sort_by(rows, &sort_key/1)
    max_score = Keyword.get(opts, :max_score, 30.0)
    verbose = Keyword.get(opts, :verbose, true)

    rows_output =
      if verbose do
        ["File | Module | Function | Complexity | Coverage | CRAP | Status"] ++
          Enum.map(sorted_rows, &render_row(&1, max_score))
      else
        [success_line(sorted_rows, max_score)]
      end

    (rows_output ++ [render_summary(rows)])
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  defp row(function, coverage_by_function) do
    key = {function.module, function.function, function.arity}
    coverage_percent = Map.get(coverage_by_function, key, 0)

    function
    |> Map.put(:coverage_percent, nil)
    |> Map.put(:score, nil)
    |> put_score(coverage_percent)
  end

  defp put_score(row, coverage_percent) do
    case Score.score(row.complexity, coverage_percent) do
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

  defp render_row(row, max_score) do
    line =
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

    cond do
      passing_scored?(row, max_score) -> green(line)
      failing?(row, max_score) -> red(line)
      true -> line
    end
  end

  defp success_line(rows, max_score) do
    rows
    |> Enum.map(&progress_marker(&1, max_score))
    |> Enum.reject(&is_nil/1)
    |> Enum.chunk_by(fn {color, _marker} -> color end)
    |> Enum.map_join(fn markers ->
      {color, _marker} = hd(markers)
      color(Enum.map_join(markers, fn {_color, marker} -> marker end), color)
    end)
  end

  defp progress_marker(row, max_score) do
    cond do
      passing_scored?(row, max_score) -> {:green, "✓"}
      failing?(row, max_score) -> {:red, "x"}
      true -> nil
    end
  end

  defp failing?(%{status: {:error, _reason}}, _max_score), do: true
  defp failing?(row, max_score), do: high_score?(row, max_score)

  defp passing_scored?(%{status: :scored, score: score}, max_score) when is_number(score),
    do: score <= max_score

  defp passing_scored?(_row, _max_score), do: false

  defp green(line),
    do: IO.ANSI.format_fragment([:green, line, :reset], true) |> IO.iodata_to_binary()

  defp red(line), do: IO.ANSI.format_fragment([:red, line, :reset], true) |> IO.iodata_to_binary()

  defp color(line, :green), do: green(line)
  defp color(line, :red), do: red(line)

  defp render_summary(rows) do
    files = rows |> Enum.map(& &1.file) |> Enum.uniq() |> length()
    scored = Enum.count(rows, &(&1.status == :scored))

    worst_score =
      rows |> Enum.map(& &1.score) |> Enum.reject(&is_nil/1) |> Enum.max(fn -> nil end)

    "Summary: files=#{files} functions=#{length(rows)} scored=#{scored} " <>
      "worst_score=#{format_score(worst_score)}"
  end

  defp format_coverage(nil), do: "missing"
  defp format_coverage(percent), do: "#{format_number(percent)}%"

  defp format_score(nil), do: "-"
  defp format_score(score), do: format_number(score)

  defp format_number(number), do: :erlang.float_to_binary(number * 1.0, decimals: 2)

  defp format_status(:scored), do: "scored"
  defp format_status({:error, reason}), do: "error: #{reason}"
end
