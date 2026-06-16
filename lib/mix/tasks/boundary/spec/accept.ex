defmodule Mix.Tasks.Boundary.Spec.Accept do
  @shortdoc "Accept current Boundary spec snapshot"
  @moduledoc false

  use Mix.Task
  use Boundary, classify_to: ExCrap.Mix

  alias ExCrap.Mix.BoundarySpec

  @task_moduledoc """
  Writes the current `mix boundary.spec` output to `priv/boundary_spec.txt`.

  This task requires interactive human approval. It has no non-interactive approval flag.
  """

  # Internal maintenance task for accepting the checked-in Boundary spec snapshot.

  @impl Mix.Task
  def run([]) do
    if !BoundarySpec.interactive?() do
      Mix.raise("Boundary spec acceptance requires interactive human approval.")
    end

    case BoundarySpec.current_spec() do
      {:ok, current} ->
        show_existing_diff(current)
        confirm!()

        case BoundarySpec.write_snapshot(current) do
          :ok ->
            Mix.shell().info("Updated Boundary spec snapshot: #{BoundarySpec.snapshot_path()}")

          {:error, reason} ->
            Mix.raise("Unable to write Boundary spec snapshot: #{inspect(reason)}")
        end

      {:error, reason} ->
        Mix.raise("Unable to produce Boundary spec: #{inspect(reason)}")
    end
  end

  @doc false
  def run([arg | _args]) do
    Mix.raise("Unexpected argument: #{arg}")
  end

  @doc false
  def shortdoc, do: @shortdoc

  @doc false
  def moduledoc, do: @task_moduledoc

  defp show_existing_diff(current) do
    case File.read(BoundarySpec.snapshot_path()) do
      {:ok, ^current} ->
        Mix.shell().info("Boundary spec snapshot already matches current output.")

      {:ok, expected} ->
        Mix.shell().info(
          "Boundary spec change to accept:\n\n" <> BoundarySpec.diff(expected, current)
        )

      {:error, :enoent} ->
        Mix.shell().info(
          "Boundary spec snapshot will be created: #{BoundarySpec.snapshot_path()}\n\n" <>
            BoundarySpec.diff("", current)
        )

      {:error, reason} ->
        Mix.raise("Boundary spec snapshot is unreadable: #{inspect(reason)}")
    end
  end

  defp confirm! do
    confirmation =
      BoundarySpec.read_confirmation()
      |> to_string()
      |> String.trim()

    if confirmation != BoundarySpec.approval_phrase() do
      Mix.raise("Boundary spec acceptance was not confirmed.")
    end
  end
end
