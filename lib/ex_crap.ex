defmodule ExCrap do
  use Boundary, exports: [BoundarySpec]

  @moduledoc """
  Public API for calculating CRAP scores from complexity and coverage data.

  Use `mix crap` for a project scan from exported Mix/Erlang coverdata. The task
  enforces a maximum CRAP score threshold (default `30`) and fails with a non-zero
  exit when any function exceeds it or any score calculation error occurs.

  Deferred work for later slices includes machine-readable formats,
  umbrella-aware defaults, third-party coverage formats, and richer reporting.
  """

  alias ExCrap.Complexity
  alias ExCrap.Coverage
  alias ExCrap.Report
  alias ExCrap.Scanner
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
  Scans project source files, imports coverdata, and builds CRAP report rows.

  The scan defaults to root `lib/**/*.ex` files. Pass `source_path: path` to scan
  another source directory. Valid projects with no analyzable function or macro
  bodies return `{:no_analyzable_functions, pattern}`.
  """
  def project_report(root, coverdata_path, opts \\ [])
      when is_binary(root) and is_binary(coverdata_path) do
    source_path = Keyword.get(opts, :source_path, "lib")
    source_pattern = root |> Scanner.source_pattern(source_path) |> Path.relative_to(root)
    source_files = Scanner.source_files(root, source_path)

    with :ok <- ensure_source_files(source_files, source_pattern),
         {:ok, functions} <- Scanner.analyze(root, source_path),
         :ok <- ensure_analyzable_functions(functions, source_pattern),
         {:ok, coverage} <- Coverage.from_coverdata(coverdata_path) do
      {:ok, Report.rows(functions, coverage, root)}
    end
  end

  @doc """
  Renders report rows as deterministic text output.
  """
  def render_report(rows, opts \\ []) do
    Report.render(rows, opts)
  end

  @doc """
  Groups rows that should fail threshold enforcement.
  """
  def failures(rows, max_score) do
    Report.failures(rows, max_score)
  end

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

  defp ensure_source_files([], source_pattern), do: {:no_source_files, source_pattern}
  defp ensure_source_files(_source_files, _source_pattern), do: :ok

  defp ensure_analyzable_functions([], source_pattern),
    do: {:no_analyzable_functions, source_pattern}

  defp ensure_analyzable_functions(_functions, _source_pattern), do: :ok

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
