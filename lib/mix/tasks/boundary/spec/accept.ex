defmodule Mix.Tasks.Boundary.Spec.Accept do
  use Mix.Task
  use Boundary, classify_to: ExCrap.Mix

  @shortdoc "Accept current Boundary spec snapshot"

  @moduledoc """
  Writes the current `mix boundary.spec` output to `priv/boundary_spec.txt`.

  This task requires interactive human approval. It has no non-interactive approval flag.
  """

  @impl Mix.Task
  def run([]) do
    unless ExCrap.BoundarySpec.interactive?() do
      Mix.raise("Boundary spec acceptance requires interactive human approval.")
    end

    with {:ok, current} <- ExCrap.BoundarySpec.current_spec() do
      show_existing_diff(current)
      confirm!()

      case ExCrap.BoundarySpec.write_snapshot(current) do
        :ok ->
          Mix.shell().info(
            "Updated Boundary spec snapshot: #{ExCrap.BoundarySpec.snapshot_path()}"
          )

        {:error, reason} ->
          Mix.raise("Unable to write Boundary spec snapshot: #{inspect(reason)}")
      end
    else
      {:error, reason} ->
        Mix.raise("Unable to produce Boundary spec: #{inspect(reason)}")
    end
  end

  def run([arg | _args]) do
    Mix.raise("Unexpected argument: #{arg}")
  end

  def shortdoc, do: @shortdoc
  def moduledoc, do: @moduledoc

  defp show_existing_diff(current) do
    case File.read(ExCrap.BoundarySpec.snapshot_path()) do
      {:ok, ^current} ->
        Mix.shell().info("Boundary spec snapshot already matches current output.")

      {:ok, expected} ->
        Mix.shell().info(
          "Boundary spec change to accept:\n\n" <> ExCrap.BoundarySpec.diff(expected, current)
        )

      {:error, :enoent} ->
        Mix.shell().info(
          "Boundary spec snapshot will be created: #{ExCrap.BoundarySpec.snapshot_path()}\n\n" <>
            ExCrap.BoundarySpec.diff("", current)
        )

      {:error, reason} ->
        Mix.raise("Boundary spec snapshot is unreadable: #{inspect(reason)}")
    end
  end

  defp confirm! do
    confirmation =
      ExCrap.BoundarySpec.read_confirmation()
      |> to_string()
      |> String.trim()

    unless confirmation == ExCrap.BoundarySpec.approval_phrase() do
      Mix.raise("Boundary spec acceptance was not confirmed.")
    end
  end
end
