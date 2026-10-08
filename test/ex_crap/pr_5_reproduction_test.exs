defmodule ExCrap.Pr5ReproductionTest do
  use ExUnit.Case, async: true

  test "alias __MODULE__, as: Self does not crash analysis" do
    source = """
    defmodule Example do
      alias __MODULE__, as: Self
      def run, do: :ok
    end
    """

    assert {:ok, [%{module: Example, function: :run}]} =
             ExCrap.Complexity.from_string(source)
  end

  for branch <- ~w(case cond with try receive) do
    test "bare #{branch} AST does not crash analysis" do
      source = "defmodule Example do\n def run, do: #{unquote(branch)}\nend"

      assert {:ok, [%{module: Example, function: :run, complexity: complexity}]} =
               ExCrap.Complexity.from_string(source)

      assert complexity == if(unquote(branch) == "try", do: 2, else: 1)
    end
  end
end
