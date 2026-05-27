defmodule Crap.CoverageTest do
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

      assert Crap.Coverage.from_function_rows(rows) == %{
               {Example, :covered, 0} => 100.0,
               {Example, :uncovered, 0} => 0.0,
               {Example, :partial, 0} => 25.0,
               {Example, :empty, 0} => 0.0
             }
    end
  end

  describe "from_coverdata/1" do
    test "imports real exported coverdata and returns function coverage", %{
      cover_active?: cover_active?
    } do
      path =
        Path.join(
          System.tmp_dir!(),
          "crap-coverage-#{System.unique_integer([:positive])}.coverdata"
        )

      unless cover_active?, do: assert({:ok, Crap} = :cover.compile_beam(Crap))

      assert {:ok, 1.0} = Crap.score(1, 100)
      assert :ok = :cover.export(String.to_charlist(path))

      unless cover_active? do
        :cover.stop()

        assert {:ok, coverage} = Crap.Coverage.from_coverdata(path)
        assert Map.fetch!(coverage, {Crap, :score, 2}) > 0
      end

      File.rm(path)
    end

    test "returns a clear error for unreadable coverdata" do
      assert Crap.Coverage.from_coverdata("/missing/nope.coverdata") ==
               {:error, {:coverdata_unreadable, "/missing/nope.coverdata"}}
    end
  end
end
