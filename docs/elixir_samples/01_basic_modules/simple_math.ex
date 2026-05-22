# Source: Canonical example inspired by Elixir stdlib patterns
# Complexity: Simple
# Constructs: defmodule, def, defp, @moduledoc, @doc, @spec, default arguments, guards
defmodule SimpleMath do
  @moduledoc """
  Basic arithmetic operations demonstrating simple module structure.
  """

  @doc """
  Adds two numbers together.
  """
  @spec add(number, number) :: number
  def add(a, b), do: a + b

  @doc """
  Subtracts b from a.
  """
  @spec subtract(number, number) :: number
  def subtract(a, b), do: a - b

  @doc """
  Multiplies two numbers, with an optional scaling factor.
  """
  @spec multiply(number, number, number) :: number
  def multiply(a, b, scale \\ 1) do
    a * b * scale
  end

  @doc """
  Safely divides a by b, returning an error tuple for zero division.
  """
  @spec safe_div(number, number) :: {:ok, float} | {:error, :division_by_zero}
  def safe_div(_a, 0), do: {:error, :division_by_zero}
  def safe_div(_a, 0.0), do: {:error, :division_by_zero}
  def safe_div(a, b), do: {:ok, a / b}

  @doc """
  Returns the absolute value.
  """
  @spec abs(number) :: number
  def abs(n) when n < 0, do: -n
  def abs(n), do: n

  @doc """
  Clamps a value between a minimum and maximum.
  """
  @spec clamp(number, number, number) :: number
  def clamp(value, min_val, max_val) when value < min_val, do: min_val
  def clamp(value, _min_val, max_val) when value > max_val, do: max_val
  def clamp(value, _min_val, _max_val), do: value

  @doc false
  defp validate_positive(n) when is_number(n) and n > 0, do: :ok
  defp validate_positive(_), do: :error
end
