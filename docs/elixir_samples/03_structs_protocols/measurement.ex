# Source: Inspired by broadway/lib/broadway/message.ex and elixirmoney/lib/money.ex
# Complexity: Moderate
# Constructs: defstruct, @enforce_keys, @type, defprotocol, defimpl,
#             pattern matching on structs, update syntax, Inspect protocol
defmodule Measurement do
  @moduledoc """
  A measurement struct with unit tracking, demonstrating struct definition,
  enforce_keys, protocol implementations, and struct pattern matching.
  """

  @type unit :: :meters | :kilometers | :miles | :feet | :celsius | :fahrenheit | :kelvin

  @type category :: :distance | :temperature

  @type t :: %__MODULE__{
          value: number,
          unit: unit,
          precision: non_neg_integer,
          metadata: %{optional(atom) => term}
        }

  @enforce_keys [:value, :unit]
  defstruct value: 0,
            unit: :meters,
            precision: 2,
            metadata: %{}

  @unit_categories %{
    meters: :distance,
    kilometers: :distance,
    miles: :distance,
    feet: :distance,
    celsius: :temperature,
    fahrenheit: :temperature,
    kelvin: :temperature
  }

  @doc """
  Creates a new measurement.

  ## Examples

      Measurement.new(100, :meters)
      Measurement.new(72.5, :fahrenheit, precision: 1)

  """
  @spec new(number, unit, keyword) :: t
  def new(value, unit, opts \\ []) when is_number(value) and is_atom(unit) do
    unless Map.has_key?(@unit_categories, unit) do
      raise ArgumentError, "unknown unit: #{inspect(unit)}"
    end

    %__MODULE__{
      value: value,
      unit: unit,
      precision: Keyword.get(opts, :precision, 2),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Returns the category of the measurement.
  """
  @spec category(t) :: category
  def category(%__MODULE__{unit: unit}), do: Map.fetch!(@unit_categories, unit)

  @doc """
  Converts a measurement to a different unit within the same category.
  """
  @spec convert(t, unit) :: {:ok, t} | {:error, :incompatible_units}
  def convert(%__MODULE__{unit: unit} = m, target_unit) do
    if category(m) == Map.get(@unit_categories, target_unit) do
      converted_value = do_convert(m.value, unit, target_unit)
      {:ok, %{m | value: converted_value, unit: target_unit}}
    else
      {:error, :incompatible_units}
    end
  end

  @doc """
  Adds two measurements of the same unit.
  """
  @spec add(t, t) :: t
  def add(%__MODULE__{unit: unit} = a, %__MODULE__{unit: unit} = b) do
    %{a | value: a.value + b.value}
  end

  @doc """
  Updates the metadata of a measurement.
  """
  @spec put_metadata(t, atom, term) :: t
  def put_metadata(%__MODULE__{metadata: metadata} = m, key, value) when is_atom(key) do
    %{m | metadata: Map.put(metadata, key, value)}
  end

  @doc """
  Scales the measurement value by a factor.
  """
  @spec scale(t, number) :: t
  def scale(%__MODULE__{} = m, factor) when is_number(factor) do
    %{m | value: m.value * factor}
  end

  @doc """
  Rounds the value to the configured precision.
  """
  @spec round(t) :: t
  def round(%__MODULE__{value: value, precision: precision} = m) do
    factor = :math.pow(10, precision)
    rounded = Kernel.round(value * factor) / factor
    %{m | value: rounded}
  end

  @doc """
  Checks if two measurements are equal (same value and unit).
  """
  @spec equal?(t, t) :: boolean
  def equal?(%__MODULE__{value: v, unit: u}, %__MODULE__{value: v, unit: u}), do: true
  def equal?(_, _), do: false

  # Distance conversions (to meters as base)
  defp do_convert(value, from, to) when from == to, do: value

  defp do_convert(value, :meters, :kilometers), do: value / 1000.0
  defp do_convert(value, :meters, :miles), do: value / 1609.344
  defp do_convert(value, :meters, :feet), do: value * 3.28084
  defp do_convert(value, :kilometers, :meters), do: value * 1000.0
  defp do_convert(value, :miles, :meters), do: value * 1609.344
  defp do_convert(value, :feet, :meters), do: value / 3.28084

  defp do_convert(value, from, to) do
    # Convert through base unit (meters for distance, celsius for temperature)
    base = to_base(value, from)
    from_base(base, to)
  end

  defp to_base(value, :meters), do: value
  defp to_base(value, :kilometers), do: value * 1000.0
  defp to_base(value, :miles), do: value * 1609.344
  defp to_base(value, :feet), do: value / 3.28084
  defp to_base(value, :celsius), do: value
  defp to_base(value, :fahrenheit), do: (value - 32) * 5.0 / 9.0
  defp to_base(value, :kelvin), do: value - 273.15

  defp from_base(value, :meters), do: value
  defp from_base(value, :kilometers), do: value / 1000.0
  defp from_base(value, :miles), do: value / 1609.344
  defp from_base(value, :feet), do: value * 3.28084
  defp from_base(value, :celsius), do: value
  defp from_base(value, :fahrenheit), do: value * 9.0 / 5.0 + 32
  defp from_base(value, :kelvin), do: value + 273.15
end

defimpl Inspect, for: Measurement do
  def inspect(%Measurement{value: value, unit: unit, precision: precision}, _opts) do
    formatted = :erlang.float_to_binary(value / 1, decimals: precision)
    "#Measurement<#{formatted} #{unit}>"
  end
end

defimpl String.Chars, for: Measurement do
  def to_string(%Measurement{value: value, unit: unit}) do
    "#{value} #{unit}"
  end
end
