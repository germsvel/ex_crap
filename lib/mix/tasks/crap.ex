defmodule Mix.Tasks.Crap do
  use Mix.Task

  @shortdoc "Print CRAP scores for project source"

  @moduledoc """
  Prints CRAP scores for Elixir source files and fails when results exceed the configured threshold.

  Usage: mix crap

      mix test --cover --export-coverage default
      mix crap
      mix crap --coverdata path/to/file.coverdata
      mix crap --max-score 30

  Coverage workflow: `mix crap` consumes persisted Mix/Erlang coverage data.
  The default path is `cover/default.coverdata`, produced by
  `mix test --cover --export-coverage default`. Plain `mix test --cover` prints
  a coverage report, but does not leave importable coverage data for a later
  `mix crap` run.

  The task scans only root `lib/**/*.ex` files. The default maximum CRAP score is
  30 (default: 30). Use `--max-score N` to override it. The task fails when any
  function exceeds the threshold or has score calculation errors. Missing function
  coverage is scored as 0%. Missing coverdata input is still a usage error.
  """

  @impl Mix.Task
  def run(args) do
    case OptionParser.parse(args,
           strict: [coverdata: :string, max_score: :string, help: :boolean]
         ) do
      {opts, [], []} ->
        if opts[:help] do
          Mix.shell().info(@moduledoc)
        else
          run_report(opts)
        end

      {_opts, [arg | _args], []} ->
        Mix.raise("Unexpected argument: #{arg}")

      {_opts, _args, [{option, _value} | _]} ->
        Mix.raise("Unknown option: #{option}")
    end
  end

  def shortdoc, do: @shortdoc
  def moduledoc, do: @moduledoc

  defp run_report(opts) do
    root = File.cwd!()

    with {:ok, max_score} <- max_score(opts),
         {:ok, functions} <- Crap.Scanner.analyze(root),
         :ok <- ensure_source_files(functions),
         {:ok, coverdata_path} <- coverdata_path(opts, root),
         {:ok, coverage} <- Crap.Coverage.from_coverdata(coverdata_path) do
      rows = Crap.Report.rows(functions, coverage, root)
      Mix.shell().info(Crap.Report.render(rows))
      enforce_threshold!(rows, max_score)
    else
      {:no_source_files, pattern} ->
        Mix.shell().info("No root #{pattern} files found.")

      {:error, :no_coverdata} ->
        Mix.shell().info("""
        No coverage data found at cover/default.coverdata.

        Run persisted coverage first:
            mix test --cover --export-coverage default

        Then run:
            mix crap

        Plain mix test --cover prints a coverage report, but does not leave importable coverage data for a later mix crap run.
        If coverage data is elsewhere, run: mix crap --coverdata path/to/file.coverdata
        """)

        Mix.raise("Coverage data is missing: cover/default.coverdata")

      {:error, {:coverdata_unreadable, path}} ->
        Mix.raise("Coverage data is unreadable: #{path}")

      {:error, {:invalid_max_score, value}} ->
        Mix.raise("Invalid --max-score: #{value}. Expected a positive number.")

      {:error, reason} ->
        Mix.raise("Unable to calculate CRAP report: #{inspect(reason)}")
    end
  end

  defp ensure_source_files([]), do: {:no_source_files, "lib/**/*.ex"}
  defp ensure_source_files(_functions), do: :ok

  defp coverdata_path(opts, root) do
    case Keyword.fetch(opts, :coverdata) do
      {:ok, path} -> {:ok, Path.expand(path, root)}
      :error -> default_coverdata_path(root)
    end
  end

  defp default_coverdata_path(root) do
    path = Path.join(root, "cover/default.coverdata")

    if File.regular?(path), do: {:ok, path}, else: {:error, :no_coverdata}
  end

  defp max_score(opts) do
    case Keyword.fetch(opts, :max_score) do
      {:ok, value} -> parse_max_score(value)
      :error -> {:ok, 30.0}
    end
  end

  defp parse_max_score(value) do
    case Float.parse(value) do
      {score, ""} when score > 0 -> {:ok, score}
      _other -> {:error, {:invalid_max_score, value}}
    end
  end

  defp enforce_threshold!(rows, max_score) do
    failures = Crap.Report.failures(rows, max_score)

    unless Enum.all?(failures, fn {_key, rows} -> rows == [] end) do
      Mix.raise(failure_message(failures, max_score))
    end
  end

  defp failure_message(failures, max_score) do
    [
      "CRAP threshold failed: max_score=#{format_number(max_score)}",
      failure_section("High scores", failures.high_scores, &high_score_line/1),
      failure_section("Score errors", failures.score_errors, &status_line/1)
    ]
    |> Enum.join("\n")
  end

  defp failure_section(title, rows, line_fun) do
    lines = rows |> Enum.take(5) |> Enum.map(line_fun)
    overflow = length(rows) - length(lines)
    suffix = if overflow > 0, do: ["  ... and #{overflow} more"], else: []

    (["#{title}: #{length(rows)}"] ++ lines ++ suffix)
    |> Enum.join("\n")
  end

  defp high_score_line(row) do
    "  #{row_identity(row)} score=#{format_number(row.score)}"
  end

  defp status_line(row) do
    "  #{row_identity(row)} status=#{format_status(row.status)}"
  end

  defp row_identity(row) do
    "#{row.file} #{inspect(row.module)}.#{row.function}/#{row.arity}"
  end

  defp format_status({:error, reason}), do: "error: #{reason}"
  defp format_status(status), do: to_string(status)

  defp format_number(number), do: :erlang.float_to_binary(number * 1.0, decimals: 2)
end
