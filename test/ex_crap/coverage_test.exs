defmodule ExCrap.CoverageTest do
  use ExUnit.Case, async: false

  setup do
    cover_active? =
      case :cover.start() do
        {:ok, _pid} ->
          on_exit(fn -> :cover.stop() end)
          false

        {:error, {:already_started, _pid}} ->
          true
      end

    {:ok, cover_active?: cover_active?}
  end

  describe "from_function_rows/1" do
    test "converts covered and uncovered counts to percentages" do
      rows = [
        {{Example, :covered, 0}, {3, 0}},
        {{Example, :uncovered, 0}, {0, 2}},
        {{Example, :partial, 0}, {1, 3}},
        {{Example, :empty, 0}, {0, 0}}
      ]

      assert ExCrap.Coverage.from_function_rows(rows) == %{
               {Example, :covered, 0} => 100.0,
               {Example, :uncovered, 0} => 0.0,
               {Example, :partial, 0} => 25.0,
               {Example, :empty, 0} => 0.0
             }
    end

    test "normalizes MACRO- prefixed function names to plain atom form" do
      rows = [
        {{Example, :"MACRO-debug", 2}, {10, 0}},
        {{Example, :regular, 1}, {5, 5}}
      ]

      result = ExCrap.Coverage.from_function_rows(rows)

      assert Map.has_key?(result, {Example, :debug, 1})
      refute Map.has_key?(result, {Example, :"MACRO-debug", 2})
      assert result[{Example, :debug, 1}] == 100.0
      assert result[{Example, :regular, 1}] == 50.0
    end
  end

  describe "from_coverdata/1" do
    @tag :tmp_dir
    test "imports real exported coverdata and returns function coverage", %{
      cover_active?: cover_active?,
      tmp_dir: tmp_dir
    } do
      path = Path.join(tmp_dir, "crap-coverage.coverdata")

      unless cover_active?, do: assert({:ok, ExCrap} = :cover.compile_beam(ExCrap))

      assert {:ok, 1.0} = ExCrap.score(1, 100)
      assert :ok = :cover.export(String.to_charlist(path))

      unless cover_active? do
        :cover.stop()

        assert {:ok, coverage} = ExCrap.Coverage.from_coverdata(path)
        assert Map.fetch!(coverage, {ExCrap, :score, 2}) > 0
      end

      File.rm(path)
    end

    test "returns a clear error for unreadable coverdata" do
      assert ExCrap.Coverage.from_coverdata("/missing/nope.coverdata") ==
               {:error, {:coverdata_unreadable, "/missing/nope.coverdata"}}
    end
  end
end
