defmodule Crap.ScannerTest do
  use ExUnit.Case, async: true

  describe "source_files/1" do
    test "returns sorted root lib source files and ignores non-source and umbrella paths" do
      root = tmp_dir("scanner-files")

      write_source(root, "lib/b.ex", "defmodule B do\n  def b, do: :ok\nend\n")
      write_source(root, "lib/a.ex", "defmodule A do\n  def a, do: :ok\nend\n")
      write_source(root, "test/a_test.exs", "defmodule ATest do\nend\n")
      write_source(root, "apps/child/lib/child.ex", "defmodule Child do\nend\n")

      assert Crap.Scanner.source_files(root) == [
               Path.join(root, "lib/a.ex"),
               Path.join(root, "lib/b.ex")
             ]
    end
  end

  describe "analyze/1" do
    test "analyzes each scanned file and attaches source file paths" do
      root = tmp_dir("scanner-analyze")

      write_source(root, "lib/example.ex", """
      defmodule ScannerExample do
        def visible?(value) do
          if value, do: true, else: false
        end
      end
      """)

      assert {:ok,
              [
                %{
                  file: file,
                  module: ScannerExample,
                  function: :visible?,
                  arity: 1,
                  complexity: 2
                }
              ]} = Crap.Scanner.analyze(root)

      assert file == Path.join(root, "lib/example.ex")
    end

    test "returns an empty result when no root lib source files exist" do
      root = tmp_dir("scanner-empty")

      assert Crap.Scanner.analyze(root) == {:ok, []}
    end
  end

  defp tmp_dir(name) do
    root = Path.join(System.tmp_dir!(), "crap-#{name}-#{System.unique_integer([:positive])}")
    File.rm_rf!(root)
    File.mkdir_p!(root)
    root
  end

  defp write_source(root, relative_path, source) do
    path = Path.join(root, relative_path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, source)
  end
end
