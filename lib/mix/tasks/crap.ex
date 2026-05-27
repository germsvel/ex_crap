defmodule Mix.Tasks.Crap do
  use Mix.Task

  @shortdoc "Print report-only CRAP scores for project source"

  @moduledoc """
  Prints report-only CRAP scores for Elixir source files.

  Usage: mix crap

      mix test --cover --export-coverage default
      mix crap
      mix crap --coverdata path/to/file.coverdata

  Coverage workflow: `mix crap` consumes persisted Mix/Erlang coverage data.
  The default path is `cover/default.coverdata`, produced by
  `mix test --cover --export-coverage default`. Plain `mix test --cover` prints
  a coverage report, but does not leave importable coverage data for a later
  `mix crap` run.

  The task scans only root `lib/**/*.ex` files. This sprint is report-only:
  high CRAP scores are displayed but do not fail CI or change the command exit
  status.
  """

  @impl Mix.Task
  def run(args) do
    case OptionParser.parse(args, strict: [coverdata: :string, help: :boolean]) do
      {opts, [], []} ->
        if opts[:help] do
          Mix.shell().info(@moduledoc)
        else
          run_report(opts)
        end

      {_opts, _args, [{option, _value} | _]} ->
        Mix.raise("Unknown option: #{option}")
    end
  end

  def shortdoc, do: @shortdoc
  def moduledoc, do: @moduledoc

  defp run_report(opts) do
    root = File.cwd!()

    with {:ok, functions} <- Crap.Scanner.analyze(root),
         :ok <- ensure_source_files(functions),
         {:ok, coverdata_path} <- coverdata_path(opts, root),
         {:ok, coverage} <- Crap.Coverage.from_coverdata(coverdata_path) do
      functions
      |> Crap.Report.rows(coverage)
      |> Crap.Report.render()
      |> Mix.shell().info()
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

      {:error, {:coverdata_unreadable, path}} ->
        Mix.raise("Coverage data is unreadable: #{path}")

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
end
