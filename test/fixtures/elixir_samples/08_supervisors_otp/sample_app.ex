# Source: Inspired by gothinkster/elixir-phoenix-realworld-example-app/lib/real_world/application.ex
#         and broadway/lib/broadway/topology.ex
# Complexity: Moderate
# Constructs: use Application, use Supervisor, start_link, child_spec,
#             supervision strategies, Task, Agent, Process.flag
defmodule SampleApp.Application do
  @moduledoc """
  The application entry point demonstrating Application behaviour.
  """
  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      {SampleApp.Config, name: SampleApp.Config},
      {SampleApp.WorkerPool, pool_size: 5},
      {Task.Supervisor, name: SampleApp.TaskSupervisor}
    ]

    opts = [strategy: :one_for_one, name: SampleApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl Application
  def stop(_state) do
    :ok
  end
end

defmodule SampleApp.Config do
  @moduledoc """
  An Agent-based configuration store.
  Demonstrates Agent usage for shared state.
  """
  use Agent

  @type t :: %{optional(atom) => term}

  @doc """
  Starts the config agent with default values.
  """
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    Agent.start_link(fn -> default_config() end, name: name)
  end

  @doc """
  Gets a configuration value.
  """
  @spec get(atom) :: term
  def get(key) do
    Agent.get(__MODULE__, &Map.get(&1, key))
  end

  @doc """
  Gets a configuration value with a default.
  """
  @spec get(atom, term) :: term
  def get(key, default) do
    Agent.get(__MODULE__, &Map.get(&1, key, default))
  end

  @doc """
  Sets a configuration value.
  """
  @spec put(atom, term) :: :ok
  def put(key, value) do
    Agent.update(__MODULE__, &Map.put(&1, key, value))
  end

  @doc """
  Returns all configuration as a map.
  """
  @spec all() :: t
  def all do
    Agent.get(__MODULE__, & &1)
  end

  defp default_config do
    %{
      max_retries: 3,
      timeout: 5_000,
      log_level: :info,
      batch_size: 100
    }
  end
end

defmodule SampleApp.WorkerPool do
  @moduledoc """
  A supervisor that manages a pool of worker processes.
  Demonstrates dynamic child specifications and supervision strategies.
  """
  use Supervisor

  @doc """
  Starts the worker pool supervisor.
  """
  def start_link(opts) do
    pool_size = Keyword.get(opts, :pool_size, 3)
    Supervisor.start_link(__MODULE__, pool_size, name: __MODULE__)
  end

  @impl Supervisor
  def init(pool_size) do
    children =
      for i <- 1..pool_size do
        Supervisor.child_spec(
          {SampleApp.Worker, id: i},
          id: :"worker_#{i}"
        )
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Runs a task asynchronously in the pool.
  """
  @spec async_run((-> term)) :: Task.t()
  def async_run(fun) when is_function(fun, 0) do
    Task.Supervisor.async_nolink(SampleApp.TaskSupervisor, fun)
  end

  @doc """
  Runs multiple tasks and collects results.
  """
  @spec async_map([term], (term -> term)) :: [term]
  def async_map(items, fun) when is_list(items) and is_function(fun, 1) do
    items
    |> Enum.map(fn item ->
      Task.Supervisor.async_nolink(SampleApp.TaskSupervisor, fn -> fun.(item) end)
    end)
    |> Task.yield_many(5_000)
    |> Enum.map(fn
      {_task, {:ok, result}} -> {:ok, result}
      {task, nil} ->
        Task.shutdown(task, :brutal_kill)
        {:error, :timeout}
      {_task, {:exit, reason}} -> {:error, reason}
    end)
  end
end

defmodule SampleApp.Worker do
  @moduledoc """
  A simple worker GenServer managed by the WorkerPool supervisor.
  """
  use GenServer

  @doc false
  def start_link(opts) do
    id = Keyword.fetch!(opts, :id)
    GenServer.start_link(__MODULE__, id, name: via(id))
  end

  @doc false
  def child_spec(opts) do
    id = Keyword.get(opts, :id, __MODULE__)

    %{
      id: id,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5_000
    }
  end

  @impl GenServer
  def init(id) do
    Process.flag(:trap_exit, true)
    {:ok, %{id: id, tasks_completed: 0, started_at: System.monotonic_time(:second)}}
  end

  @impl GenServer
  def handle_call(:status, _from, state) do
    uptime = System.monotonic_time(:second) - state.started_at
    reply = Map.put(state, :uptime_seconds, uptime)
    {:reply, reply, state}
  end

  @impl GenServer
  def handle_cast({:process, _data}, state) do
    {:noreply, %{state | tasks_completed: state.tasks_completed + 1}}
  end

  @impl GenServer
  def terminate(_reason, _state) do
    :ok
  end

  defp via(id), do: {:global, {__MODULE__, id}}
end
