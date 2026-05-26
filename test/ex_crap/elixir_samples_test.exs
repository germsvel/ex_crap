defmodule ExCrap.ElixirSamplesTest do
  use ExUnit.Case, async: true

  @samples_root Path.expand("../fixtures/elixir_samples", __DIR__)

  @expected_sample_paths [
    "01_basic_modules/simple_math.ex",
    "01_basic_modules/string_processor.ex",
    "02_typespecs/serializer.ex",
    "03_structs_protocols/measurement.ex",
    "04_behaviours/pipeline.ex",
    "05_macros/registerable.ex",
    "06_pattern_matching/data_validator.ex",
    "07_genserver/cache_janitor.ex",
    "08_supervisors_otp/sample_app.ex",
    "09_protocols/renderable.ex",
    "10_advanced/task_runner.ex"
  ]

  @expected_summaries %{
    "01_basic_modules/simple_math.ex" => %{count: 7, total: 14, max: 3},
    "01_basic_modules/string_processor.ex" => %{count: 9, total: 28, max: 6},
    "02_typespecs/serializer.ex" => %{count: 6, total: 17, max: 7},
    "03_structs_protocols/measurement.ex" => %{count: 13, total: 36, max: 8},
    "04_behaviours/pipeline.ex" => %{count: 13, total: 48, max: 10},
    "05_macros/registerable.ex" => %{count: 6, total: 11, max: 5},
    "06_pattern_matching/data_validator.ex" => %{count: 21, total: 89, max: 15},
    "07_genserver/cache_janitor.ex" => %{count: 15, total: 30, max: 7},
    "08_supervisors_otp/sample_app.ex" => %{count: 19, total: 27, max: 7},
    "09_protocols/renderable.ex" => %{count: 11, total: 23, max: 5},
    "10_advanced/task_runner.ex" => %{count: 12, total: 47, max: 10}
  }

  describe "canonical sample fixtures" do
    test "canonical samples live with test fixtures" do
      assert @samples_root == Path.expand("../fixtures/elixir_samples", __DIR__)
    end

    test "discovers only canonical samples" do
      assert canonical_sample_paths() == absolute_expected_sample_paths()
      assert Enum.sort(Map.keys(@expected_summaries)) == @expected_sample_paths
      refute Enum.any?(canonical_sample_paths(), &String.contains?(&1, "_raw_originals"))
    end

    test "all canonical samples analyze successfully" do
      for path <- canonical_sample_paths() do
        assert {:ok, results} = ExCrap.Complexity.from_file(path), path
        assert results != [], path

        assert Enum.all?(results, fn result ->
                 is_integer(result.complexity) and result.complexity > 0
               end),
               path
      end
    end

    test "canonical sample aggregate complexity summaries remain stable" do
      for path <- canonical_sample_paths() do
        relative_path = Path.relative_to(path, @samples_root)
        assert {:ok, results} = ExCrap.Complexity.from_file(path), relative_path

        summary = %{
          count: length(results),
          total: Enum.sum(Enum.map(results, & &1.complexity)),
          max: results |> Enum.map(& &1.complexity) |> Enum.max()
        }

        assert summary == Map.fetch!(@expected_summaries, relative_path), relative_path
      end
    end
  end

  defp canonical_sample_paths do
    @samples_root
    |> Path.join("[0-9][0-9]_*/*.ex")
    |> Path.wildcard()
    |> Enum.sort()
  end

  defp absolute_expected_sample_paths do
    Enum.map(@expected_sample_paths, &Path.join(@samples_root, &1))
  end
end
