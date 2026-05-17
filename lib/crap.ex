defmodule Crap do
  @moduledoc """
  Public API for calculating CRAP scores from complexity and coverage data.

  Use `mix crap` for a project scan from exported Mix/Erlang coverdata. The task
  enforces a maximum CRAP score threshold (default `30`) and fails with a non-zero
  exit when any function exceeds it or any score calculation error occurs.

  Deferred work for later slices includes machine-readable formats, broader path
  selection, umbrella support, third-party coverage formats, and richer reporting.
  """

  alias Crap.Complexity

  @doc """
  Analyzes one Elixir source file and combines each discovered function with explicit coverage.

  This is a single-file convenience wrapper around `Crap.Complexity.from_file/1`.
  It does not perform project-wide scanning or coverage discovery.
  """
  def analyze_file(path, coverage_by_function) when is_map(coverage_by_function) do
    with {:ok, functions} <- Complexity.from_file(path) do
      {:ok, Enum.map(functions, &score_function(&1, coverage_by_function))}
    end
  end

  def analyze_file(_path, _coverage_by_function), do: {:error, :invalid_coverage_map}

  @doc """
  Analyzes Elixir source and combines each discovered function with explicit coverage.

  `coverage_by_function` must be a map keyed by `{module, function_name, arity}`:

      %{{Example, :visible?, 1} => 75.0}

  Coverage values are percentages from `0` to `100`. Functions without a matching
  coverage entry are scored as `0%` covered. This function does not discover or
  ingest coverage automatically.
  """
  def analyze_string(source, coverage_by_function) when is_map(coverage_by_function) do
    with {:ok, functions} <- Complexity.from_string(source) do
      {:ok, Enum.map(functions, &score_function(&1, coverage_by_function))}
    end
  end

  def analyze_string(_source, _coverage_by_function), do: {:error, :invalid_coverage_map}

  @doc """
  Calculates the canonical CRAP score for a complexity and coverage percentage.

  The formula is:

      complexity^2 * (1 - coverage_percent / 100)^3 + complexity

  `complexity` must be numeric and non-negative. `coverage_percent` must be numeric
  and between `0` and `100` inclusive. Fractional scores are preserved.
  """
  def score(complexity, coverage_percent) do
    with :ok <- validate_complexity(complexity),
         :ok <- validate_coverage(coverage_percent) do
      uncovered = 1 - coverage_percent / 100
      {:ok, complexity * complexity * uncovered * uncovered * uncovered + complexity * 1.0}
    end
  end

  defp validate_complexity(complexity) when is_number(complexity) and complexity >= 0, do: :ok
  defp validate_complexity(_complexity), do: {:error, :invalid_complexity}

  defp validate_coverage(coverage_percent)
       when is_number(coverage_percent) and coverage_percent >= 0 and coverage_percent <= 100,
       do: :ok

  defp validate_coverage(_coverage_percent), do: {:error, :invalid_coverage}

  defp score_function(function, coverage_by_function) do
    key = {function.module, function.function, function.arity}
    coverage_percent = Map.get(coverage_by_function, key, 0)

    case score(function.complexity, coverage_percent) do
      {:ok, score} ->
        function
        |> Map.put(:coverage_percent, coverage_percent)
        |> Map.put(:score, score)
        |> Map.put(:status, :scored)

      {:error, reason} ->
        Map.put(function, :status, {:error, reason})
    end
  end
end
