defmodule ExCrap.ScannerTest do
  use ExUnit.Case, async: false

  describe "source_files/1" do
    @tag :tmp_dir
    test "returns sorted root lib source files and ignores non-source and umbrella paths", %{
      tmp_dir: tmp_dir
    } do
      write_source(tmp_dir, "lib/b.ex", "defmodule B do\n  def b, do: :ok\nend\n")
      write_source(tmp_dir, "lib/a.ex", "defmodule A do\n  def a, do: :ok\nend\n")
      write_source(tmp_dir, "test/a_test.exs", "defmodule ATest do\nend\n")
      write_source(tmp_dir, "apps/child/lib/child.ex", "defmodule Child do\nend\n")

      assert ExCrap.Scanner.source_files(tmp_dir) == [
               Path.join(tmp_dir, "lib/a.ex"),
               Path.join(tmp_dir, "lib/b.ex")
             ]
    end

    test "uses the current working directory by default" do
      root = File.cwd!()

      assert files = ExCrap.Scanner.source_files()
      assert Path.join(root, "lib/ex_crap.ex") in files
      assert Enum.all?(files, &String.starts_with?(&1, Path.join(root, "lib/")))
    end

    @tag :tmp_dir
    test "returns sorted source files from a custom source directory", %{tmp_dir: tmp_dir} do
      write_source(tmp_dir, "fixtures/b.ex", "defmodule B do\n  def b, do: :ok\nend\n")
      write_source(tmp_dir, "fixtures/a.ex", "defmodule A do\n  def a, do: :ok\nend\n")
      write_source(tmp_dir, "lib/ignored.ex", "defmodule Ignored do\n  def ok, do: :ok\nend\n")
      write_source(tmp_dir, "fixtures/ignored.exs", "defmodule IgnoredScript do\nend\n")

      assert ExCrap.Scanner.source_files(tmp_dir, "fixtures") == [
               Path.join(tmp_dir, "fixtures/a.ex"),
               Path.join(tmp_dir, "fixtures/b.ex")
             ]
    end

    @tag :tmp_dir
    test "expands absolute custom source directories", %{tmp_dir: tmp_dir} do
      fixtures = Path.join(tmp_dir, "fixtures")

      path =
        write_source(
          tmp_dir,
          "fixtures/example.ex",
          "defmodule Example do\n  def ok, do: :ok\nend\n"
        )

      assert ExCrap.Scanner.source_files(tmp_dir, fixtures) == [path]
    end
  end

  describe "analyze/1" do
    @tag :tmp_dir
    test "analyzes each scanned file and attaches source file paths", %{tmp_dir: tmp_dir} do
      write_source(tmp_dir, "lib/example.ex", """
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
              ]} = ExCrap.Scanner.analyze(tmp_dir)

      assert file == Path.join(tmp_dir, "lib/example.ex")
    end

    test "uses the current working directory when analyzing by default" do
      root = File.cwd!()

      assert {:ok, results} = ExCrap.Scanner.analyze()

      assert Enum.any?(results, fn result ->
               result.file == Path.join(root, "lib/ex_crap.ex") and result.module == ExCrap
             end)
    end

    @tag :tmp_dir
    test "returns an empty result when no root lib source files exist", %{tmp_dir: tmp_dir} do
      assert ExCrap.Scanner.analyze(tmp_dir) == {:ok, []}
    end

    @tag :tmp_dir
    test "returns an empty result when source files have no analyzable function bodies", %{
      tmp_dir: tmp_dir
    } do
      write_source(tmp_dir, "lib/driver.ex", """
      defprotocol Example.Driver do
        def visit(initial_struct, path)
      end
      """)

      assert ExCrap.Scanner.analyze(tmp_dir) == {:ok, []}
    end

    @tag :tmp_dir
    test "continues analyzing files after valid files with no analyzable function bodies", %{
      tmp_dir: tmp_dir
    } do
      write_source(tmp_dir, "lib/a_driver.ex", """
      defprotocol Example.Driver do
        def visit(initial_struct, path)
      end
      """)

      write_source(tmp_dir, "lib/b_example.ex", """
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
              ]} = ExCrap.Scanner.analyze(tmp_dir)

      assert file == Path.join(tmp_dir, "lib/b_example.ex")
    end

    @tag :tmp_dir
    test "analyzes files with default-argument function heads", %{tmp_dir: tmp_dir} do
      path =
        write_source(tmp_dir, "lib/phoenix_test.ex", ~S"""
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
              ]} = ExCrap.Scanner.analyze(tmp_dir)
    end

    @tag :tmp_dir
    test "returns a file-specific error for invalid source", %{tmp_dir: tmp_dir} do
      path = write_source(tmp_dir, "lib/bad.ex", "defmodule")

      assert ExCrap.Scanner.analyze(tmp_dir) == {:error, {path, :invalid_source}}
    end

    @tag :tmp_dir
    test "analyzes files from a custom source directory", %{tmp_dir: tmp_dir} do
      write_source(tmp_dir, "fixtures/example.ex", """
      defmodule ScannerCustomExample do
        def ok, do: :ok
      end
      """)

      write_source(tmp_dir, "lib/ignored.ex", """
      defmodule ScannerIgnoredExample do
        def ignored, do: :ok
      end
      """)

      assert {:ok,
              [
                %{
                  file: file,
                  module: ScannerCustomExample,
                  function: :ok,
                  arity: 0,
                  complexity: 1
                }
              ]} = ExCrap.Scanner.analyze(tmp_dir, "fixtures")

      assert file == Path.join(tmp_dir, "fixtures/example.ex")
    end
  end

  defp write_source(root, relative_path, source) do
    path = Path.join(root, relative_path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, source)
    path
  end
end
