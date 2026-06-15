defmodule ExCrap.Mix.BoundarySpecTest do
  use ExUnit.Case, async: false

  alias ExCrap.Mix.BoundarySpec

  setup do
    on_exit(fn ->
      Process.delete({BoundarySpec, :current_spec})
      Process.delete({BoundarySpec, :snapshot_path})
      Process.delete({BoundarySpec, :interactive?})
      Process.delete({BoundarySpec, :confirmation})
      Process.delete({BoundarySpec, :stdio_opts})
    end)

    :ok
  end

  test "exposes snapshot path and approval phrase" do
    assert BoundarySpec.snapshot_path() == "priv/boundary_spec.txt"
    assert BoundarySpec.approval_phrase() == "approve boundary spec change"
  end

  test "current spec does not export Boundary maintenance module from public boundary" do
    assert {:ok, spec} = BoundarySpec.current_spec()

    refute spec =~ "exports: BoundarySpec"
  end

  test "snapshot path can be overridden for tests" do
    Process.put({BoundarySpec, :snapshot_path}, "tmp/boundary_spec.txt")

    assert BoundarySpec.snapshot_path() == "tmp/boundary_spec.txt"
  end

  test "current spec override returns fixed output" do
    Process.put({BoundarySpec, :current_spec}, "fixed\n")

    assert BoundarySpec.current_spec() == {:ok, "fixed\n"}
  end

  test "current spec override can return a result tuple" do
    Process.put({BoundarySpec, :current_spec}, {:ok, "fixed\n"})

    assert BoundarySpec.current_spec() == {:ok, "fixed\n"}
  end

  test "interactive mode and confirmation can be overridden" do
    Process.put({BoundarySpec, :interactive?}, false)
    Process.put({BoundarySpec, :confirmation}, "nope\n")

    refute BoundarySpec.interactive?()
    assert BoundarySpec.read_confirmation() == "nope\n"
  end

  test "interactive mode is not controlled by ANSI configuration" do
    previous = Application.get_env(:elixir, :ansi_enabled)

    try do
      Application.put_env(:elixir, :ansi_enabled, true)
      Process.put({BoundarySpec, :stdio_opts}, stdin: false, terminal: false)

      refute BoundarySpec.interactive?()
    after
      if is_nil(previous) do
        Application.delete_env(:elixir, :ansi_enabled)
      else
        Application.put_env(:elixir, :ansi_enabled, previous)
      end
    end
  end

  test "interactive mode uses stdio tty options" do
    Process.put({BoundarySpec, :stdio_opts}, stdin: true, terminal: true)

    assert BoundarySpec.interactive?()
  end

  @tag :tmp_dir
  test "check_snapshot reports missing snapshot", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "boundary_spec.txt")

    assert {:error, {:missing_snapshot, ^path}} = BoundarySpec.check_snapshot("current\n", path)
  end

  @tag :tmp_dir
  test "check_snapshot passes when snapshot matches", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "boundary_spec.txt")
    File.write!(path, "current\n")

    assert :ok = BoundarySpec.check_snapshot("current\n", path)
  end

  @tag :tmp_dir
  test "check_snapshot returns diff when snapshot differs", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "boundary_spec.txt")
    File.write!(path, "OldBoundary\n")

    assert {:error, {:changed, diff}} = BoundarySpec.check_snapshot("NewBoundary\n", path)
    assert diff =~ "--- priv/boundary_spec.txt"
    assert diff =~ "+++ current boundary spec"
    assert diff =~ "-OldBoundary"
    assert diff =~ "+NewBoundary"
  end

  test "diff preserves blank line changes" do
    diff = BoundarySpec.diff("OldBoundary\n\nAfter\n", "NewBoundary\nAfter\n")

    assert diff =~ "-OldBoundary"
    assert diff =~ "\n-\n"
    assert diff =~ "+NewBoundary"
    assert diff =~ "After"
  end

  test "diff with identical inputs only emits headers" do
    assert BoundarySpec.diff("Same\n", "Same\n") ==
             "--- priv/boundary_spec.txt\n+++ current boundary spec\n"
  end

  @tag :tmp_dir
  test "check_snapshot reports unreadable snapshot", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "boundary_spec.txt")
    File.mkdir!(path)

    assert {:error, {:snapshot_unreadable, ^path, reason}} =
             BoundarySpec.check_snapshot("current\n", path)

    assert reason != :enoent
  end

  @tag :tmp_dir
  test "write_snapshot creates parent directories", %{tmp_dir: tmp_dir} do
    path = Path.join([tmp_dir, "priv", "boundary_spec.txt"])

    assert :ok = BoundarySpec.write_snapshot("current\n", path)
    assert File.read!(path) == "current\n"
  end
end
