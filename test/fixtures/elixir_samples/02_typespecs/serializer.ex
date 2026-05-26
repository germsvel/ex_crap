# Source: Inspired by jason/lib/jason.ex typespecs and plug/lib/plug.ex callback types
# Complexity: Moderate
# Constructs: @type, @typep, @opaque, @spec, @callback, union types, literal types,
#             keyword types, map types, function types, recursive types
defmodule Serializer do
  @moduledoc """
  A serializer specification with rich type definitions.
  Demonstrates the full range of Elixir typespec constructs.
  """

  # Simple named types
  @type format :: :json | :msgpack | :etf | :csv

  # Union types with literals
  @type escape_mode :: :json | :unicode_safe | :html_safe | :javascript_safe

  # Keyword option types
  @type encode_opt ::
          {:escape, escape_mode}
          | {:pretty, boolean | keyword}
          | {:sort_keys, boolean}

  @type decode_opt ::
          {:keys, :atoms | :atoms! | :strings | :copy | (String.t() -> term)}
          | {:strings, :reference | :copy}
          | {:objects, :maps | :ordered_objects}

  # Recursive type
  @type json_value ::
          nil
          | boolean
          | number
          | String.t()
          | [json_value]
          | %{optional(String.t()) => json_value}

  # Map with specific keys
  @type config :: %{
          required(:format) => format,
          required(:version) => pos_integer,
          optional(:escape) => escape_mode,
          optional(:pretty) => boolean,
          optional(:max_depth) => non_neg_integer | :infinity
        }

  # Private type
  @typep internal_state :: %{
           buffer: iodata,
           depth: non_neg_integer,
           opts: [encode_opt]
         }

  # Opaque type
  @opaque encoder :: %__MODULE__{
            format: format,
            opts: [encode_opt],
            state: internal_state
          }

  defstruct format: :json, opts: [], state: %{buffer: [], depth: 0, opts: []}

  # Callbacks for behaviour
  @callback encode(term, [encode_opt]) :: {:ok, iodata} | {:error, term}
  @callback decode(binary, [decode_opt]) :: {:ok, json_value} | {:error, term}
  @callback supports_format?(format) :: boolean

  @doc """
  Creates a new encoder with the given format and options.
  """
  @spec new(format, [encode_opt]) :: encoder
  def new(format, opts \\ []) when format in [:json, :msgpack, :etf, :csv] do
    %__MODULE__{
      format: format,
      opts: opts,
      state: %{buffer: [], depth: 0, opts: opts}
    }
  end

  @doc """
  Encodes a value to a binary string.
  """
  @spec encode(encoder, json_value) :: {:ok, binary} | {:error, term}
  def encode(%__MODULE__{format: :json} = _encoder, value) do
    case do_encode_json(value) do
      {:ok, iodata} -> {:ok, IO.iodata_to_binary(iodata)}
      error -> error
    end
  end

  def encode(%__MODULE__{format: format}, _value) do
    {:error, {:unsupported_format, format}}
  end

  @doc """
  Encodes a value, raising on error.
  """
  @spec encode!(encoder, json_value) :: binary
  def encode!(encoder, value) do
    case encode(encoder, value) do
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, "encoding failed: #{inspect(reason)}"
    end
  end

  @doc """
  Returns the configured format.
  """
  @spec format(encoder) :: format
  def format(%__MODULE__{format: f}), do: f

  # Private encoding implementations

  @spec do_encode_json(json_value) :: {:ok, iodata} | {:error, term}
  defp do_encode_json(nil), do: {:ok, "null"}
  defp do_encode_json(true), do: {:ok, "true"}
  defp do_encode_json(false), do: {:ok, "false"}
  defp do_encode_json(i) when is_integer(i), do: {:ok, Integer.to_string(i)}
  defp do_encode_json(f) when is_float(f), do: {:ok, Float.to_string(f)}

  defp do_encode_json(s) when is_binary(s) do
    {:ok, [?", escape_string(s), ?"]}
  end

  defp do_encode_json(list) when is_list(list) do
    elements =
      list
      |> Enum.map(fn item ->
        case do_encode_json(item) do
          {:ok, encoded} -> encoded
          error -> throw(error)
        end
      end)
      |> Enum.intersperse(",")

    {:ok, [?[, elements, ?]]}
  catch
    {:error, _} = error -> error
  end

  defp do_encode_json(map) when is_map(map) do
    pairs =
      map
      |> Enum.map(fn {k, v} ->
        with {:ok, ek} <- do_encode_json(to_string(k)),
             {:ok, ev} <- do_encode_json(v) do
          [ek, ?:, ev]
        else
          error -> throw(error)
        end
      end)
      |> Enum.intersperse(",")

    {:ok, [?{, pairs, ?}]}
  catch
    {:error, _} = error -> error
  end

  defp do_encode_json(other), do: {:error, {:unsupported_type, other}}

  @spec escape_string(String.t()) :: iodata
  defp escape_string(string) do
    String.replace(string, ~S("), ~S(\"))
  end
end
