# Source: Inspired by elixir/lib/mix/lib/mix/exceptions.ex, tesla/lib/tesla/middleware/retry.ex,
#         and gen_stage/examples/producer_consumer.exs
# Complexity: Complex
# Constructs: defexception, @impl true, raise/rescue, for comprehension with filters,
#             Stream/Enum pipelines, recursive functions, tagged tuples,
#             exponential backoff, :timer, :rand, Bitwise, try/catch
defmodule TaskRunner do
  @moduledoc """
  A task runner with retry logic, error handling, and streaming.
  Demonstrates advanced Elixir patterns.
  """

  # Custom exceptions

  defmodule TaskError do
    @moduledoc "Raised when a task fails after exhausting retries."
    defexception [:task, :attempts, :message, :last_error]

    @impl true
    def exception(opts) do
      task = opts[:task]
      attempts = opts[:attempts]
      last_error = opts[:last_error]

      message =
        "Task #{inspect(task)} failed after #{attempts} attempt(s): #{inspect(last_error)}"

      %__MODULE__{
        task: task,
        attempts: attempts,
        message: message,
        last_error: last_error
      }
    end
  end

  defmodule TimeoutError do
    @moduledoc "Raised when a task exceeds its timeout."
    defexception [:task, :timeout, :message]

    @impl true
    def exception(opts) do
      task = opts[:task]
      timeout = opts[:timeout]
      message = "Task #{inspect(task)} timed out after #{timeout}ms"
      %__MODULE__{task: task, timeout: timeout, message: message}
    end
  end

  defmodule ValidationError do
    @moduledoc "Raised when task input validation fails."
    defexception message: "validation failed"
  end

  # Types

  @type task_fun :: (term -> {:ok, term} | {:error, term})
  @type retry_opts :: [
          max_retries: non_neg_integer,
          delay: pos_integer,
          max_delay: pos_integer,
          jitter_factor: float
        ]

  @default_retry_opts [
    max_retries: 3,
    delay: 100,
    max_delay: 5_000,
    jitter_factor: 0.2
  ]

  # Public API

  @doc """
  Runs a task function with retry logic.
  """
  @spec run_with_retry(task_fun, term, retry_opts) :: {:ok, term} | {:error, term}
  def run_with_retry(fun, input, opts \\ []) when is_function(fun, 1) do
    opts = Keyword.merge(@default_retry_opts, opts)
    max_retries = Keyword.fetch!(opts, :max_retries)
    do_retry(fun, input, opts, 0, max_retries, nil)
  end

  @doc """
  Runs a task function, raising on failure.
  """
  @spec run_with_retry!(task_fun, term, retry_opts) :: term
  def run_with_retry!(fun, input, opts \\ []) do
    case run_with_retry(fun, input, opts) do
      {:ok, result} ->
        result

      {:error, last_error} ->
        max_retries = Keyword.get(opts, :max_retries, 3)

        raise TaskError,
          task: fun,
          attempts: max_retries + 1,
          last_error: last_error
    end
  end

  @doc """
  Processes a list of items through a pipeline of functions,
  collecting results and errors separately.
  """
  @spec batch_process([term], [task_fun]) :: %{ok: [term], errors: [{term, term}]}
  def batch_process(items, pipeline) when is_list(items) and is_list(pipeline) do
    items
    |> Enum.map(fn item ->
      result =
        Enum.reduce_while(pipeline, {:ok, item}, fn fun, {:ok, value} ->
          case fun.(value) do
            {:ok, new_value} -> {:cont, {:ok, new_value}}
            {:error, _} = error -> {:halt, error}
          end
        end)

      {item, result}
    end)
    |> Enum.split_with(fn {_item, result} -> match?({_, {:ok, _}}, {nil, result}) end)
    |> then(fn {successes, failures} ->
      %{
        ok: Enum.map(successes, fn {_item, {:ok, value}} -> value end),
        errors:
          for {item, {:error, reason}} <- failures do
            {item, reason}
          end
      }
    end)
  end

  @doc """
  Creates a stream that generates items with exponential backoff delays.
  Useful for polling patterns.
  """
  @spec backoff_stream(pos_integer, pos_integer, float) :: Enumerable.t()
  def backoff_stream(base_delay, max_delay, jitter_factor \\ 0.1) do
    Stream.unfold(0, fn attempt ->
      delay = calculate_delay(base_delay, max_delay, attempt, jitter_factor)
      {delay, attempt + 1}
    end)
  end

  @doc """
  Processes items in chunks with a transformation function.
  Demonstrates for comprehension with filters and guards.
  """
  @spec chunk_transform([term], pos_integer, (term -> term)) :: [[term]]
  def chunk_transform(items, chunk_size, transform_fn)
      when is_list(items) and is_integer(chunk_size) and chunk_size > 0 do
    for chunk <- Enum.chunk_every(items, chunk_size),
        result = Enum.map(chunk, transform_fn),
        result != [] do
      result
    end
  end

  @doc """
  Filters and transforms a map using comprehension with pattern matching.
  """
  @spec filter_map(map(), (term, term -> boolean), (term -> term)) :: map()
  def filter_map(map, filter_fn, transform_fn)
      when is_map(map) and is_function(filter_fn, 2) and is_function(transform_fn, 1) do
    for {key, value} <- map,
        filter_fn.(key, value),
        into: %{} do
      {key, transform_fn.(value)}
    end
  end

  @doc """
  Recursively flattens a nested structure to a flat keyword list with dotted keys.

  ## Examples

      flatten_nested(%{a: %{b: 1, c: %{d: 2}}})
      #=> [{"a.b", 1}, {"a.c.d", 2}]

  """
  @spec flatten_nested(map(), String.t()) :: [{String.t(), term}]
  def flatten_nested(map, prefix \\ "") when is_map(map) do
    Enum.flat_map(map, fn {key, value} ->
      full_key =
        case prefix do
          "" -> to_string(key)
          _ -> "#{prefix}.#{key}"
        end

      case value do
        v when is_map(v) and not is_struct(v) -> flatten_nested(v, full_key)
        v -> [{full_key, v}]
      end
    end)
  end

  @doc """
  Wraps a function call with error normalization.
  """
  @spec safe_call((-> term)) :: {:ok, term} | {:error, term}
  def safe_call(fun) when is_function(fun, 0) do
    try do
      {:ok, fun.()}
    rescue
      e in [ArgumentError, RuntimeError] ->
        {:error, {:exception, Exception.message(e)}}
    catch
      :exit, reason -> {:error, {:exit, reason}}
      :throw, value -> {:error, {:throw, value}}
    end
  end

  # Private functions

  defp do_retry(_fun, _input, _opts, attempt, max_retries, last_error)
       when attempt > max_retries do
    {:error, last_error}
  end

  defp do_retry(fun, input, opts, attempt, max_retries, _last_error) do
    case fun.(input) do
      {:ok, _} = success ->
        success

      {:error, reason} when attempt < max_retries ->
        delay = calculate_delay(
          Keyword.fetch!(opts, :delay),
          Keyword.fetch!(opts, :max_delay),
          attempt,
          Keyword.fetch!(opts, :jitter_factor)
        )

        Process.sleep(delay)
        do_retry(fun, input, opts, attempt + 1, max_retries, reason)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp calculate_delay(base, cap, attempt, jitter_factor) do
    factor = Bitwise.bsl(1, attempt)
    max_sleep = min(cap, base * factor)
    jitter = 1 - jitter_factor * :rand.uniform()
    trunc(max_sleep * jitter)
  end
end
