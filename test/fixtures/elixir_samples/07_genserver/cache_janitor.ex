# Source: Inspired by cachex/lib/cachex/services/janitor.ex
# Complexity: Moderate
# Constructs: use GenServer, init/1, handle_call/3, handle_cast/2, handle_info/2,
#             start_link/1, :erlang.send_after, GenServer.call, GenServer.cast,
#             @spec, pattern matching on state, Map operations
defmodule CacheJanitor do
  @moduledoc """
  A periodic cache cleanup GenServer inspired by Cachex's Janitor service.
  Demonstrates all standard GenServer callbacks with real-world patterns.
  """
  use GenServer

  @type entry :: %{
          key: term,
          value: term,
          inserted_at: integer,
          ttl: integer | :infinity
        }

  @type state :: %{
          name: atom,
          entries: %{optional(term) => entry},
          interval: pos_integer,
          max_size: pos_integer | :infinity,
          stats: %{
            purge_count: non_neg_integer,
            last_purge: integer | nil,
            total_purged: non_neg_integer
          }
        }

  @default_interval 30_000
  @default_max_size 10_000

  # Client API

  @doc """
  Starts the cache janitor process.
  """
  @spec start_link(keyword) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Stores a value in the cache with an optional TTL in milliseconds.
  """
  @spec put(GenServer.server(), term, term, integer | :infinity) :: :ok
  def put(server \\ __MODULE__, key, value, ttl \\ :infinity) do
    GenServer.call(server, {:put, key, value, ttl})
  end

  @doc """
  Retrieves a value from the cache.
  """
  @spec get(GenServer.server(), term) :: {:ok, term} | :miss
  def get(server \\ __MODULE__, key) do
    GenServer.call(server, {:get, key})
  end

  @doc """
  Deletes a key from the cache.
  """
  @spec delete(GenServer.server(), term) :: :ok
  def delete(server \\ __MODULE__, key) do
    GenServer.cast(server, {:delete, key})
  end

  @doc """
  Returns statistics about the janitor's operation.
  """
  @spec stats(GenServer.server()) :: map()
  def stats(server \\ __MODULE__) do
    GenServer.call(server, :stats)
  end

  @doc """
  Forces an immediate purge of expired entries.
  """
  @spec purge(GenServer.server()) :: {non_neg_integer, map()}
  def purge(server \\ __MODULE__) do
    GenServer.call(server, :purge)
  end

  # Server callbacks

  @impl GenServer
  def init(opts) do
    interval = Keyword.get(opts, :interval, @default_interval)
    max_size = Keyword.get(opts, :max_size, @default_max_size)
    name = Keyword.get(opts, :name, __MODULE__)

    state = %{
      name: name,
      entries: %{},
      interval: interval,
      max_size: max_size,
      stats: %{
        purge_count: 0,
        last_purge: nil,
        total_purged: 0
      }
    }

    schedule_purge(interval)
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:put, key, value, ttl}, _from, state) do
    now = System.monotonic_time(:millisecond)

    entry = %{
      key: key,
      value: value,
      inserted_at: now,
      ttl: ttl
    }

    new_entries = Map.put(state.entries, key, entry)
    new_state = maybe_evict(%{state | entries: new_entries})
    {:reply, :ok, new_state}
  end

  def handle_call({:get, key}, _from, state) do
    case Map.fetch(state.entries, key) do
      {:ok, entry} ->
        if expired?(entry) do
          new_entries = Map.delete(state.entries, key)
          {:reply, :miss, %{state | entries: new_entries}}
        else
          {:reply, {:ok, entry.value}, state}
        end

      :error ->
        {:reply, :miss, state}
    end
  end

  def handle_call(:stats, _from, state) do
    stats =
      state.stats
      |> Map.put(:entry_count, map_size(state.entries))
      |> Map.put(:max_size, state.max_size)
      |> Map.put(:interval, state.interval)

    {:reply, stats, state}
  end

  def handle_call(:purge, _from, state) do
    {count, new_state} = do_purge(state)
    {:reply, {count, new_state.stats}, new_state}
  end

  @impl GenServer
  def handle_cast({:delete, key}, state) do
    new_entries = Map.delete(state.entries, key)
    {:noreply, %{state | entries: new_entries}}
  end

  @impl GenServer
  def handle_info(:purge, state) do
    {_count, new_state} = do_purge(state)
    schedule_purge(new_state.interval)
    {:noreply, new_state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private functions

  defp schedule_purge(interval) do
    :erlang.send_after(interval, self(), :purge)
  end

  defp do_purge(state) do
    now = System.monotonic_time(:millisecond)

    {kept, expired_count} =
      Enum.reduce(state.entries, {%{}, 0}, fn {key, entry}, {acc, count} ->
        if expired?(entry, now) do
          {acc, count + 1}
        else
          {Map.put(acc, key, entry), count}
        end
      end)

    new_stats = %{
      state.stats
      | purge_count: state.stats.purge_count + 1,
        last_purge: now,
        total_purged: state.stats.total_purged + expired_count
    }

    {expired_count, %{state | entries: kept, stats: new_stats}}
  end

  defp expired?(%{ttl: :infinity}), do: false

  defp expired?(%{inserted_at: inserted_at, ttl: ttl}) do
    now = System.monotonic_time(:millisecond)
    inserted_at + ttl < now
  end

  defp expired?(%{ttl: :infinity}, _now), do: false

  defp expired?(%{inserted_at: inserted_at, ttl: ttl}, now) do
    inserted_at + ttl < now
  end

  defp maybe_evict(%{max_size: :infinity} = state), do: state

  defp maybe_evict(%{entries: entries, max_size: max_size} = state)
       when map_size(entries) <= max_size do
    state
  end

  defp maybe_evict(%{entries: entries, max_size: max_size} = state) do
    overflow = map_size(entries) - max_size

    evict_keys =
      entries
      |> Enum.sort_by(fn {_k, v} -> v.inserted_at end)
      |> Enum.take(overflow)
      |> Enum.map(fn {k, _v} -> k end)

    new_entries = Map.drop(entries, evict_keys)
    %{state | entries: new_entries}
  end
end
