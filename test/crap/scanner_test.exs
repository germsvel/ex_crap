defmodule Crap.ScannerTest do
  use ExUnit.Case, async: false

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

    test "uses the current working directory by default" do
      root = tmp_dir("scanner-files-default-root")

      path =
        write_source(root, "lib/example.ex", "defmodule Example do\n  def ok, do: :ok\nend\n")

      File.cd!(root, fn ->
        assert [file] = Crap.Scanner.source_files()
        assert String.ends_with?(file, "/lib/example.ex")
        assert File.read!(file) == File.read!(path)
      end)
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

    test "uses the current working directory when analyzing by default" do
      root = tmp_dir("scanner-analyze-default-root")

      path =
        write_source(root, "lib/example.ex", "defmodule Example do\n  def ok, do: :ok\nend\n")

      File.cd!(root, fn ->
        assert {:ok,
                [
                  %{
                    file: file,
                    module: Example,
                    function: :ok,
                    arity: 0,
                    complexity: 1
                  }
                ]} = Crap.Scanner.analyze()

        assert String.ends_with?(file, "/lib/example.ex")
        assert File.read!(file) == File.read!(path)
      end)
    end

    test "returns an empty result when no root lib source files exist" do
      root = tmp_dir("scanner-empty")

      assert Crap.Scanner.analyze(root) == {:ok, []}
    end

    test "returns an empty result when source files have no analyzable function bodies" do
      root = tmp_dir("scanner-no-analyzable-functions")

      write_source(root, "lib/driver.ex", """
      defprotocol Example.Driver do
        def visit(initial_struct, path)
      end
      """)

      assert Crap.Scanner.analyze(root) == {:ok, []}
    end

    test "continues analyzing files after valid files with no analyzable function bodies" do
      root = tmp_dir("scanner-mixed-analyzable-functions")

      write_source(root, "lib/a_driver.ex", """
      defprotocol Example.Driver do
        def visit(initial_struct, path)
      end
      """)

      write_source(root, "lib/b_example.ex", """
      defmodule ScannerExample do
        def ok, do: :ok
      end
      """)

      assert {:ok,
              [
                %{
                  file: file,
                  module: ScannerExample,
                  function: :ok,
                  arity: 0,
                  complexity: 1
                }
              ]} = Crap.Scanner.analyze(root)

      assert file == Path.join(root, "lib/b_example.ex")
    end

    test "analyzes files with default-argument function heads" do
      root = tmp_dir("scanner-default-argument-head")

      path =
        write_source(root, "lib/phoenix_test.ex", ~S"""
        defmodule PhoenixTest do
          def check(session, label, opts \\ [exact: true])

          def check(session, label, opts) when is_binary(label) and is_list(opts) do
            {session, label, opts}
          end
        end
        """)

      assert {:ok,
              [
                %{
                  file: ^path,
                  module: PhoenixTest,
                  function: :check,
                  arity: 3,
                  complexity: 2
                }
              ]} = Crap.Scanner.analyze(root)
    end

    test "returns a file-specific error for invalid source" do
      root = tmp_dir("scanner-invalid-source")
      path = write_source(root, "lib/bad.ex", "defmodule")

      assert Crap.Scanner.analyze(root) == {:error, {path, :invalid_source}}
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
    path
  end
end
