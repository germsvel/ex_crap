defmodule ExCrap do
  use Boundary

  @moduledoc """
  Public API for calculating CRAP scores from complexity and coverage data.

  Use `mix crap` for a project scan from exported Mix/Erlang coverdata. The task
  enforces a maximum CRAP score threshold (default `30`) and fails with a non-zero
  exit when any function exceeds it or any score calculation error occurs.

  Deferred work for later slices includes machine-readable formats, broader path
  selection, umbrella support, third-party coverage formats, and richer reporting.
  """

  alias ExCrap.Complexity
  alias ExCrap.Score

  @doc """
  Analyzes one Elixir source file and combines each discovered function with explicit coverage.

  This is a single-file convenience wrapper around `ExCrap.Complexity.from_file/1`.
  Valid files with no analyzable function or macro bodies return `{:ok, []}`.
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

  Valid source with no analyzable function or macro bodies returns `{:ok, []}`.
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
    Score.score(complexity, coverage_percent)
  end

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
