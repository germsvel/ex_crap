# Source: Inspired by plug/lib/plug.ex behaviour and tesla/lib/tesla/middleware/*.ex
# Complexity: Moderate
# Constructs: @behaviour, @callback, @optional_callbacks, @impl, defstruct,
#             multi-clause pattern matching, keyword validation
defmodule Pipeline do
  @moduledoc """
  A pipeline behaviour for processing data through a chain of steps.
  Inspired by Plug's architecture.
  """

  @type opts ::
          binary
          | atom
          | integer
          | [opts]
          | %{optional(opts) => opts}

  @type result :: {:ok, map()} | {:halt, map()} | {:error, term}

  @callback init(opts) :: opts
  @callback call(data :: map(), opts) :: result

  @optional_callbacks [init: 1]

  @doc """
  Runs a list of pipeline steps against the given data.
  """
  @spec run(map(), [{module, opts} | (map() -> result)]) :: result
  def run(data, steps) when is_map(data) and is_list(steps) do
    do_run(data, steps)
  end

  defp do_run(data, [{mod, opts} | rest]) when is_atom(mod) do
    initialized_opts =
      if function_exported?(mod, :init, 1) do
        mod.init(opts)
      else
        opts
      end

    case mod.call(data, initialized_opts) do
      {:ok, data} -> do_run(data, rest)
      {:halt, data} -> {:halt, data}
      {:error, _} = error -> error
    end
  end

  defp do_run(data, [fun | rest]) when is_function(fun, 1) do
    case fun.(data) do
      {:ok, data} -> do_run(data, rest)
      {:halt, data} -> {:halt, data}
      {:error, _} = error -> error
    end
  end

  defp do_run(data, []), do: {:ok, data}
end

# A simple step that adds a timestamp
defmodule Pipeline.Steps.Timestamp do
  @moduledoc """
  Adds a timestamp to the data map.
  """
  @behaviour Pipeline

  @impl Pipeline
  def init(opts), do: Keyword.get(opts, :key, :timestamp)

  @impl Pipeline
  def call(data, key) do
    {:ok, Map.put(data, key, System.system_time(:millisecond))}
  end
end

# A validation step that checks required fields
defmodule Pipeline.Steps.Validate do
  @moduledoc """
  Validates that required fields are present in the data.
  """
  @behaviour Pipeline

  @impl Pipeline
  def init(opts) do
    %{
      required: Keyword.get(opts, :required, []),
      types: Keyword.get(opts, :types, %{})
    }
  end

  @impl Pipeline
  def call(data, %{required: required, types: types}) do
    with :ok <- check_required(data, required),
         :ok <- check_types(data, types) do
      {:ok, data}
    end
  end

  defp check_required(data, required) do
    missing = Enum.filter(required, fn key -> not Map.has_key?(data, key) end)

    case missing do
      [] -> :ok
      keys -> {:error, {:missing_fields, keys}}
    end
  end

  defp check_types(data, types) do
    errors =
      Enum.reduce(types, [], fn {key, expected_type}, acc ->
        case Map.fetch(data, key) do
          {:ok, value} ->
            if matches_type?(value, expected_type), do: acc, else: [{key, expected_type} | acc]

          :error ->
            acc
        end
      end)

    case errors do
      [] -> :ok
      _ -> {:error, {:type_mismatch, errors}}
    end
  end

  defp matches_type?(value, :string) when is_binary(value), do: true
  defp matches_type?(value, :integer) when is_integer(value), do: true
  defp matches_type?(value, :float) when is_float(value), do: true
  defp matches_type?(value, :number) when is_number(value), do: true
  defp matches_type?(value, :boolean) when is_boolean(value), do: true
  defp matches_type?(value, :atom) when is_atom(value), do: true
  defp matches_type?(value, :list) when is_list(value), do: true
  defp matches_type?(value, :map) when is_map(value), do: true
  defp matches_type?(_, _), do: false
end

# A step that transforms specific fields
defmodule Pipeline.Steps.Transform do
  @moduledoc """
  Applies transformation functions to specified fields.
  """
  @behaviour Pipeline

  @impl Pipeline
  def init(opts), do: opts

  @impl Pipeline
  def call(data, transformations) when is_list(transformations) do
    result =
      Enum.reduce(transformations, data, fn {key, fun}, acc ->
        case Map.fetch(acc, key) do
          {:ok, value} -> Map.put(acc, key, fun.(value))
          :error -> acc
        end
      end)

    {:ok, result}
  end
end

# A conditional halt step
defmodule Pipeline.Steps.Guard do
  @moduledoc """
  Halts the pipeline if a condition is met.
  """
  @behaviour Pipeline

  @impl Pipeline
  def init(opts) do
    case Keyword.fetch(opts, :when) do
      {:ok, fun} when is_function(fun, 1) -> fun
      _ -> raise ArgumentError, "Guard requires a :when option with an arity-1 function"
    end
  end

  @impl Pipeline
  def call(data, condition_fn) do
    if condition_fn.(data) do
      {:halt, Map.put(data, :halted_by, __MODULE__)}
    else
      {:ok, data}
    end
  end
end
