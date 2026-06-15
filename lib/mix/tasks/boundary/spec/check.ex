defmodule Mix.Tasks.Boundary.Spec.Check do
  use Mix.Task
  use Boundary, classify_to: ExCrap.Mix

  @shortdoc "Verify Boundary spec snapshot"
  @task_moduledoc """
  Verifies that `mix boundary.spec` matches `priv/boundary_spec.txt`.

  If the output changed, review the diff and run `mix boundary.spec.accept` only
  when the architecture change is intentional.
  """

  @moduledoc false

  # Internal maintenance task for verifying the checked-in Boundary spec snapshot.

  @impl Mix.Task
  def run([]) do
    with {:ok, current} <- ExCrap.BoundarySpec.current_spec() do
      case ExCrap.BoundarySpec.check_snapshot(current) do
        :ok ->
          Mix.shell().info("Boundary spec matches #{ExCrap.BoundarySpec.snapshot_path()}.")

        {:error, {:missing_snapshot, path}} ->
          Mix.raise(
            "Boundary spec snapshot is missing: #{path}. Run mix boundary.spec.accept after human review."
          )

        {:error, {:changed, diff}} ->
          Mix.shell().info("Boundary spec changed:\n\n" <> diff)

          Mix.shell().info(
            "Review the diff. If intentional, run mix boundary.spec.accept as a human approval step."
          )

          Mix.raise("Boundary spec changed")

        {:error, {:snapshot_unreadable, path, reason}} ->
          Mix.raise("Boundary spec snapshot is unreadable: #{path} (#{inspect(reason)})")
      end
    else
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
end
