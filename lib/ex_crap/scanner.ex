defmodule ExCrap.Scanner do
  @moduledoc false

  use Boundary, deps: [ExCrap.Complexity]

  # Scans root `source_path/**/*.ex` files for project-level CRAP analysis.

  alias ExCrap.Complexity

  @doc false
  def source_files(root \\ File.cwd!(), source_path \\ "lib")
      when is_binary(root) and is_binary(source_path) do
    root
    |> source_pattern(source_path)
    |> Path.wildcard()
    |> Enum.sort()
  end

  @doc false
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

  @doc false
  def source_pattern(root, source_path) when is_binary(root) and is_binary(source_path) do
    source_path
    |> Path.expand(root)
    |> Path.join("**/*.ex")
  end
end
