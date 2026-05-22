# Source: Inspired by plug/lib/plug/builder.ex and jason/lib/encoder.ex
# Complexity: Complex
# Constructs: defmacro, __using__, @before_compile, quote/unquote, unquote_splicing,
#             Macro.expand, Module.register_attribute, accumulate: true,
#             module attribute access at compile time, AST manipulation
defmodule Registerable do
  @moduledoc """
  A macro module that provides a registry pattern via `use`.
  Modules that `use Registerable` can register handlers at compile time,
  which get compiled into a dispatch function.

  Inspired by Plug.Builder's compile-time plug pipeline and
  Jason.Encoder's __deriving__ macro.
  """

  @doc """
  When used, sets up the module to accumulate handlers and compile
  them into a dispatch/2 function at compile time.
  """
  defmacro __using__(opts) do
    default_action = Keyword.get(opts, :default_action, :passthrough)

    quote do
      import Registerable, only: [register: 2, register: 3]
      Module.register_attribute(__MODULE__, :registered_handlers, accumulate: true)
      @before_compile Registerable
      @registerable_default_action unquote(default_action)
    end
  end

  @doc """
  Registers a handler for a given event name with optional options.
  """
  defmacro register(event_name, handler, opts \\ []) do
    quote do
      @registered_handlers {unquote(event_name), unquote(handler), unquote(opts)}
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    handlers = Module.get_attribute(env.module, :registered_handlers) |> Enum.reverse()
    default_action = Module.get_attribute(env.module, :registerable_default_action)

    dispatch_clauses =
      for {event_name, handler, opts} <- handlers do
        quote do
          def dispatch(unquote(event_name), data) do
            unquote(handler).(data, unquote(Macro.escape(opts)))
          end
        end
      end

    default_clause =
      case default_action do
        :passthrough ->
          quote do
            def dispatch(_event, data), do: {:ok, data}
          end

        :error ->
          quote do
            def dispatch(event, _data), do: {:error, {:unknown_event, event}}
          end
      end

    list_body = Enum.map(handlers, fn {name, _handler, _opts} -> name end)

    list_fn =
      quote do
        @doc "Returns all registered event names."
        def registered_events, do: unquote(list_body)
      end

    count_fn =
      quote do
        @doc "Returns the count of registered handlers."
        def handler_count, do: unquote(length(handlers))
      end

    quote do
      unquote_splicing(dispatch_clauses)
      unquote(default_clause)
      unquote(list_fn)
      unquote(count_fn)
    end
  end
end

# Example of a module using the macro
defmodule EventProcessor do
  @moduledoc """
  Demonstrates usage of the Registerable macro.
  """
  use Registerable, default_action: :error

  register :user_created, &EventProcessor.handle_user_created/2
  register :order_placed, &EventProcessor.handle_order_placed/2, notify: true
  register :item_shipped, &EventProcessor.handle_item_shipped/2

  @doc "Handles user creation events."
  def handle_user_created(data, _opts) do
    {:ok, Map.put(data, :processed_at, System.system_time(:second))}
  end

  @doc "Handles order placement events."
  def handle_order_placed(data, opts) do
    data =
      if Keyword.get(opts, :notify, false) do
        Map.put(data, :notification_sent, true)
      else
        data
      end

    {:ok, data}
  end

  @doc "Handles item shipment events."
  def handle_item_shipped(data, _opts) do
    {:ok, Map.put(data, :status, :shipped)}
  end
end
