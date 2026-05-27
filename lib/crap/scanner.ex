defmodule Crap.Scanner do
  @moduledoc """
  Scans root project source files for CRAP analysis.

  This scanner is intentionally limited to root `lib/**/*.ex` files. It does
  not scan umbrella child apps or arbitrary caller-provided paths.
  """

  alias Crap.Complexity

  @doc """
  Returns sorted root `lib/**/*.ex` files under `root`.
  """
  def source_files(root \\ File.cwd!()) when is_binary(root) do
    root
    |> Path.join("lib/**/*.ex")
    |> Path.wildcard()
    |> Enum.sort()
  end

  @doc """
  Analyzes all root source files and attaches each result's source file path.
  """
  def analyze(root \\ File.cwd!()) when is_binary(root) do
    root
    |> source_files()
    |> Enum.reduce_while({:ok, []}, fn path, {:ok, acc} ->
      case Complexity.from_file(path) do
        {:ok, results} ->
          rows = Enum.map(results, &Map.put(&1, :file, path))
          {:cont, {:ok, acc ++ rows}}

        {:error, reason} ->
          {:halt, {:error, {path, reason}}}
      end
    end)
  end
end
