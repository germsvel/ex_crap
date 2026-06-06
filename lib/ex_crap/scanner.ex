defmodule ExCrap.Scanner do
  use Boundary, deps: [ExCrap.Complexity]

  @moduledoc """
  Scans project source files for CRAP analysis.

  This scanner defaults to root `lib/**/*.ex` files and can scan another source
  directory when one is provided.
  """

  alias ExCrap.Complexity

  @doc """
  Returns sorted `.ex` source files under `source_path`.
  """
  def source_files(root \\ File.cwd!(), source_path \\ "lib")
      when is_binary(root) and is_binary(source_path) do
    root
    |> source_pattern(source_path)
    |> Path.wildcard()
    |> Enum.sort()
  end

  @doc """
  Analyzes all selected source files and attaches each result's source file path.
  """
  def analyze(root \\ File.cwd!(), source_path \\ "lib")
      when is_binary(root) and is_binary(source_path) do
    root
    |> source_files(source_path)
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

  def source_pattern(root, source_path) when is_binary(root) and is_binary(source_path) do
    source_path
    |> Path.expand(root)
    |> Path.join("**/*.ex")
  end
end
