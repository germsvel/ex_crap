# Source: Inspired by ecto/lib/ecto/changeset.ex, plug/lib/plug.ex, tesla/lib/tesla/middleware/retry.ex
# Complexity: Complex
# Constructs: case, cond, with, multi-clause functions, nested pattern matching,
#             pin operator, map destructuring, tuple matching, tagged tuples,
#             comprehensions, recursive processing
defmodule DataValidator do
  @moduledoc """
  A data validation module demonstrating complex pattern matching and control flow.
  Inspired by Ecto.Changeset patterns.
  """

  @type error :: {String.t(), keyword}
  @type field :: atom

  @type t :: %__MODULE__{
          data: map(),
          changes: map(),
          errors: [{field, error}],
          valid?: boolean,
          required: [field],
          types: %{optional(field) => atom}
        }

  defstruct data: %{},
            changes: %{},
            errors: [],
            valid?: true,
            required: [],
            types: %{}

  @doc """
  Creates a new validator from source data and a type schema.
  """
  @spec new(map(), %{optional(field) => atom}) :: t
  def new(data, types) when is_map(data) and is_map(types) do
    %__MODULE__{data: data, types: types}
  end

  @doc """
  Casts permitted fields from params into the changeset.
  Uses `with` for clean error flow.
  """
  @spec cast(t, map(), [field]) :: t
  def cast(%__MODULE__{} = validator, params, permitted) when is_map(params) and is_list(permitted) do
    params = normalize_keys(params)

    Enum.reduce(permitted, validator, fn field, acc ->
      with {:ok, raw_value} <- fetch_param(params, field),
           {:ok, type} <- fetch_type(acc.types, field),
           {:ok, cast_value} <- cast_field(raw_value, type) do
        put_change(acc, field, cast_value)
      else
        :missing -> acc
        {:error, reason} -> add_error(acc, field, "is invalid", reason: reason)
      end
    end)
  end

  @doc """
  Validates that the given fields are present.
  """
  @spec validate_required(t, [field]) :: t
  def validate_required(%__MODULE__{} = validator, fields) when is_list(fields) do
    validator = %{validator | required: validator.required ++ fields}

    Enum.reduce(fields, validator, fn field, acc ->
      value = get_field(acc, field)

      cond do
        is_nil(value) ->
          add_error(acc, field, "can't be blank", validation: :required)

        is_binary(value) and String.trim(value) == "" ->
          add_error(acc, field, "can't be blank", validation: :required)

        true ->
          acc
      end
    end)
  end

  @doc """
  Validates a field's value against a list of allowed values.
  """
  @spec validate_inclusion(t, field, [term]) :: t
  def validate_inclusion(%__MODULE__{} = validator, field, values) when is_list(values) do
    case get_field(validator, field) do
      nil ->
        validator

      value ->
        if value in values do
          validator
        else
          add_error(validator, field, "is invalid", validation: :inclusion, enum: values)
        end
    end
  end

  @doc """
  Validates a string field's length.
  """
  @spec validate_length(t, field, keyword) :: t
  def validate_length(%__MODULE__{} = validator, field, opts) when is_list(opts) do
    case get_field(validator, field) do
      value when is_binary(value) ->
        length = String.length(value)
        do_validate_length(validator, field, length, opts)

      _ ->
        validator
    end
  end

  @doc """
  Validates a numeric field is within a range.
  """
  @spec validate_number(t, field, keyword) :: t
  def validate_number(%__MODULE__{} = validator, field, opts) do
    case get_field(validator, field) do
      value when is_number(value) ->
        validator
        |> maybe_validate_gt(field, value, opts)
        |> maybe_validate_lt(field, value, opts)
        |> maybe_validate_gte(field, value, opts)
        |> maybe_validate_lte(field, value, opts)

      _ ->
        validator
    end
  end

  @doc """
  Applies a custom validation function.
  """
  @spec validate_change(t, field, (field, term -> [{field, error}])) :: t
  def validate_change(%__MODULE__{} = validator, field, fun) when is_function(fun, 2) do
    case Map.fetch(validator.changes, field) do
      {:ok, value} ->
        case fun.(field, value) do
          [] -> validator
          errors when is_list(errors) -> Enum.reduce(errors, validator, fn {f, {msg, opts}}, acc -> add_error(acc, f, msg, opts) end)
        end

      :error ->
        validator
    end
  end

  @doc """
  Gets a field value, checking changes first, then data.
  Uses the pin operator for matching.
  """
  @spec get_field(t, field) :: term
  def get_field(%__MODULE__{changes: changes, data: data}, field) do
    case Map.fetch(changes, field) do
      {:ok, value} -> value
      :error -> Map.get(data, field)
    end
  end

  @doc """
  Applies the changes if the validator is valid.
  """
  @spec apply_changes(t) :: map()
  def apply_changes(%__MODULE__{data: data, changes: changes, valid?: true}) do
    Map.merge(data, changes)
  end

  def apply_changes(%__MODULE__{valid?: false} = validator) do
    raise ArgumentError, "cannot apply changes: #{inspect(validator.errors)}"
  end

  @doc """
  Applies an action, returning {:ok, data} or {:error, validator}.
  """
  @spec apply_action(t, atom) :: {:ok, map()} | {:error, t}
  def apply_action(%__MODULE__{valid?: true} = validator, _action) do
    {:ok, apply_changes(validator)}
  end

  def apply_action(%__MODULE__{valid?: false} = validator, action) do
    {:error, %{validator | required: [action | validator.required]}}
  end

  # Private functions

  defp put_change(%__MODULE__{} = validator, field, value) do
    %{validator | changes: Map.put(validator.changes, field, value)}
  end

  defp add_error(%__MODULE__{} = validator, field, message, opts \\ []) do
    error = {field, {message, opts}}
    %{validator | errors: [error | validator.errors], valid?: false}
  end

  defp normalize_keys(params) do
    for {key, value} <- params, into: %{} do
      case key do
        k when is_atom(k) -> {k, value}
        k when is_binary(k) -> {String.to_existing_atom(k), value}
      end
    end
  rescue
    ArgumentError -> params
  end

  defp fetch_param(params, field) do
    case Map.fetch(params, field) do
      {:ok, value} -> {:ok, value}
      :error -> :missing
    end
  end

  defp fetch_type(types, field) do
    case Map.fetch(types, field) do
      {:ok, type} -> {:ok, type}
      :error -> {:ok, :any}
    end
  end

  defp cast_field(value, :any), do: {:ok, value}
  defp cast_field(value, :string) when is_binary(value), do: {:ok, value}
  defp cast_field(value, :integer) when is_integer(value), do: {:ok, value}

  defp cast_field(value, :integer) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> {:error, :invalid_integer}
    end
  end

  defp cast_field(value, :float) when is_float(value), do: {:ok, value}
  defp cast_field(value, :float) when is_integer(value), do: {:ok, value / 1}

  defp cast_field(value, :float) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> {:ok, float}
      _ -> {:error, :invalid_float}
    end
  end

  defp cast_field(value, :boolean) when is_boolean(value), do: {:ok, value}
  defp cast_field("true", :boolean), do: {:ok, true}
  defp cast_field("false", :boolean), do: {:ok, false}
  defp cast_field(_, type), do: {:error, {:invalid_type, type}}

  defp do_validate_length(validator, field, length, opts) do
    validator
    |> check_length_constraint(field, length, :min, opts)
    |> check_length_constraint(field, length, :max, opts)
    |> check_length_constraint(field, length, :is, opts)
  end

  defp check_length_constraint(validator, field, length, :min, opts) do
    case Keyword.fetch(opts, :min) do
      {:ok, min} when length < min ->
        add_error(validator, field, "should be at least %{count} character(s)",
          count: min, validation: :length, kind: :min)

      _ -> validator
    end
  end

  defp check_length_constraint(validator, field, length, :max, opts) do
    case Keyword.fetch(opts, :max) do
      {:ok, max} when length > max ->
        add_error(validator, field, "should be at most %{count} character(s)",
          count: max, validation: :length, kind: :max)

      _ -> validator
    end
  end

  defp check_length_constraint(validator, field, length, :is, opts) do
    case Keyword.fetch(opts, :is) do
      {:ok, ^length} -> validator
      {:ok, expected} ->
        add_error(validator, field, "should be %{count} character(s)",
          count: expected, validation: :length, kind: :is)
      :error -> validator
    end
  end

  defp maybe_validate_gt(validator, field, value, opts) do
    case Keyword.fetch(opts, :greater_than) do
      {:ok, bound} when value > bound -> validator
      {:ok, bound} -> add_error(validator, field, "must be greater than %{number}", number: bound)
      :error -> validator
    end
  end

  defp maybe_validate_lt(validator, field, value, opts) do
    case Keyword.fetch(opts, :less_than) do
      {:ok, bound} when value < bound -> validator
      {:ok, bound} -> add_error(validator, field, "must be less than %{number}", number: bound)
      :error -> validator
    end
  end

  defp maybe_validate_gte(validator, field, value, opts) do
    case Keyword.fetch(opts, :greater_than_or_equal_to) do
      {:ok, bound} when value >= bound -> validator
      {:ok, bound} -> add_error(validator, field, "must be greater than or equal to %{number}", number: bound)
      :error -> validator
    end
  end

  defp maybe_validate_lte(validator, field, value, opts) do
    case Keyword.fetch(opts, :less_than_or_equal_to) do
      {:ok, bound} when value <= bound -> validator
      {:ok, bound} -> add_error(validator, field, "must be less than or equal to %{number}", number: bound)
      :error -> validator
    end
  end
end
