defmodule Mix.Tasks.Boundary.Spec.CheckTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias ExCrap.BoundarySpec
  alias Mix.Tasks.Boundary.Spec.Check

  setup do
    on_exit(fn ->
      Process.delete({BoundarySpec, :current_spec})
      Process.delete({BoundarySpec, :snapshot_path})
    end)

    :ok
  end

  @tag :tmp_dir
  test "passes when current spec matches snapshot", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "boundary_spec.txt")
    File.write!(path, "current\n")
    Process.put({BoundarySpec, :snapshot_path}, path)
    Process.put({BoundarySpec, :current_spec}, "current\n")

    output = capture_io(fn -> Check.run([]) end)

    assert output =~ "Boundary spec matches"
  end

  @tag :tmp_dir
  test "raises when snapshot is missing", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "boundary_spec.txt")
    Process.put({BoundarySpec, :snapshot_path}, path)
    Process.put({BoundarySpec, :current_spec}, "current\n")

    assert_raise Mix.Error, ~r/Boundary spec snapshot is missing/, fn ->
      Check.run([])
    end
  end

  @tag :tmp_dir
  test "prints diff and raises when snapshot changed", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "boundary_spec.txt")
    File.write!(path, "OldBoundary\n")
    Process.put({BoundarySpec, :snapshot_path}, path)
    Process.put({BoundarySpec, :current_spec}, "NewBoundary\n")

    output =
      capture_io(fn ->
        assert_raise Mix.Error, ~r/Boundary spec changed/, fn ->
          Check.run([])
        end
      end)

    assert output =~ "--- priv/boundary_spec.txt"
    assert output =~ "+++ current boundary spec"
    assert output =~ "-OldBoundary"
    assert output =~ "+NewBoundary"
    assert output =~ "mix boundary.spec.accept"
  end

  test "raises on unexpected arguments" do
    assert_raise Mix.Error, ~r/Unexpected argument: unexpected/, fn ->
      Check.run(["unexpected"])
    end
  end

  @tag :tmp_dir
  test "raises when snapshot is unreadable", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "boundary_spec.txt")
    File.mkdir!(path)
    Process.put({BoundarySpec, :snapshot_path}, path)
    Process.put({BoundarySpec, :current_spec}, "current\n")

    assert_raise Mix.Error, ~r/Boundary spec snapshot is unreadable/, fn ->
      Check.run([])
    end
  end

  @tag :tmp_dir
  test "raises when current Boundary spec cannot be produced", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "boundary_spec.txt")
    File.write!(path, "current\n")
    Process.put({BoundarySpec, :snapshot_path}, path)
    Process.put({BoundarySpec, :current_spec}, {:error, :boom})

    assert_raise Mix.Error, ~r/Unable to produce Boundary spec: :boom/, fn ->
      Check.run([])
    end
  end

  test "documents task purpose" do
    assert Check.shortdoc() =~ "Verify Boundary spec snapshot"
    assert Check.moduledoc() =~ "mix boundary.spec"
    assert Check.moduledoc() =~ "mix boundary.spec.accept"
  end
end
