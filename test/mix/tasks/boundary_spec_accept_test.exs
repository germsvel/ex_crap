defmodule Mix.Tasks.Boundary.Spec.AcceptTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias ExCrap.Mix.BoundarySpec
  alias Mix.Tasks.Boundary.Spec.Accept

  setup do
    on_exit(fn ->
      Process.delete({BoundarySpec, :current_spec})
      Process.delete({BoundarySpec, :snapshot_path})
      Process.delete({BoundarySpec, :interactive?})
      Process.delete({BoundarySpec, :confirmation})
    end)

    :ok
  end

  @tag :tmp_dir
  test "refuses to write without interactive approval", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "boundary_spec.txt")
    Process.put({BoundarySpec, :snapshot_path}, path)
    Process.put({BoundarySpec, :current_spec}, "current\n")
    Process.put({BoundarySpec, :interactive?}, false)

    assert_raise Mix.Error, ~r/requires interactive human approval/, fn ->
      Accept.run([])
    end

    refute File.exists?(path)
  end

  @tag :tmp_dir
  test "refuses to write when confirmation phrase does not match", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "boundary_spec.txt")
    Process.put({BoundarySpec, :snapshot_path}, path)
    Process.put({BoundarySpec, :current_spec}, "current\n")
    Process.put({BoundarySpec, :interactive?}, true)
    Process.put({BoundarySpec, :confirmation}, "nope\n")

    capture_io(fn ->
      assert_raise Mix.Error, ~r/Boundary spec acceptance was not confirmed/, fn ->
        Accept.run([])
      end
    end)

    refute File.exists?(path)
  end

  @tag :tmp_dir
  test "matching snapshot still requires confirmation before writing", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "boundary_spec.txt")
    File.write!(path, "current\n")
    Process.put({BoundarySpec, :snapshot_path}, path)
    Process.put({BoundarySpec, :current_spec}, "current\n")
    Process.put({BoundarySpec, :interactive?}, true)
    Process.put({BoundarySpec, :confirmation}, "nope\n")

    output =
      capture_io(fn ->
        assert_raise Mix.Error, ~r/Boundary spec acceptance was not confirmed/, fn ->
          Accept.run([])
        end
      end)

    assert output =~ "already matches"
    assert File.read!(path) == "current\n"
  end

  @tag :tmp_dir
  test "writes snapshot after exact confirmation", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "boundary_spec.txt")
    Process.put({BoundarySpec, :snapshot_path}, path)
    Process.put({BoundarySpec, :current_spec}, "CurrentBoundary\n")
    Process.put({BoundarySpec, :interactive?}, true)
    Process.put({BoundarySpec, :confirmation}, "approve boundary spec change\n")

    output = capture_io(fn -> Accept.run([]) end)

    assert File.read!(path) == "CurrentBoundary\n"
    assert output =~ "+CurrentBoundary"
    assert output =~ "Updated Boundary spec snapshot"
  end

  @tag :tmp_dir
  test "prints diff before confirmed write when snapshot differs", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "boundary_spec.txt")
    File.write!(path, "OldBoundary\n")
    Process.put({BoundarySpec, :snapshot_path}, path)
    Process.put({BoundarySpec, :current_spec}, "NewBoundary\n")
    Process.put({BoundarySpec, :interactive?}, true)
    Process.put({BoundarySpec, :confirmation}, "approve boundary spec change\n")

    output = capture_io(fn -> Accept.run([]) end)

    assert output =~ "--- priv/boundary_spec.txt"
    assert output =~ "+++ current boundary spec"
    assert output =~ "-OldBoundary"
    assert output =~ "+NewBoundary"
    assert File.read!(path) == "NewBoundary\n"
  end

  @tag :tmp_dir
  test "raises when snapshot is unreadable", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "boundary_spec.txt")
    File.mkdir!(path)
    Process.put({BoundarySpec, :snapshot_path}, path)
    Process.put({BoundarySpec, :current_spec}, "current\n")
    Process.put({BoundarySpec, :interactive?}, true)
    Process.put({BoundarySpec, :confirmation}, "approve boundary spec change\n")

    assert_raise Mix.Error, ~r/Boundary spec snapshot is unreadable/, fn ->
      Accept.run([])
    end
  end

  @tag :tmp_dir
  test "raises when current Boundary spec cannot be produced", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "boundary_spec.txt")
    File.write!(path, "current\n")
    Process.put({BoundarySpec, :snapshot_path}, path)
    Process.put({BoundarySpec, :current_spec}, {:error, :boom})
    Process.put({BoundarySpec, :interactive?}, true)
    Process.put({BoundarySpec, :confirmation}, "approve boundary spec change\n")

    assert_raise Mix.Error, ~r/Unable to produce Boundary spec: :boom/, fn ->
      Accept.run([])
    end
  end

  @tag :tmp_dir
  test "raises when snapshot cannot be written", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "boundary_spec.txt")
    File.write!(path, "current\n")
    File.chmod!(path, 0o400)

    on_exit(fn -> File.chmod(path, 0o600) end)

    Process.put({BoundarySpec, :snapshot_path}, path)
    Process.put({BoundarySpec, :current_spec}, "current\n")
    Process.put({BoundarySpec, :interactive?}, true)
    Process.put({BoundarySpec, :confirmation}, "approve boundary spec change\n")

    capture_io(fn ->
      assert_raise Mix.Error, ~r/Unable to write Boundary spec snapshot/, fn ->
        Accept.run([])
      end
    end)
  end

  test "raises on unexpected arguments" do
    assert_raise Mix.Error, ~r/Unexpected argument: unexpected/, fn ->
      Accept.run(["unexpected"])
    end
  end

  test "documents task purpose" do
    assert Accept.shortdoc() =~ "Accept current Boundary spec snapshot"
    assert Accept.moduledoc() =~ "mix boundary.spec"
    assert Accept.moduledoc() =~ "interactive human approval"
  end
end
