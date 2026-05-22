# Source: Inspired by phoenix_html/lib/phoenix_html/safe.ex and jason/lib/encoder.ex
# Complexity: Moderate
# Constructs: defprotocol, defimpl (for multiple types), @fallback_to_any,
#             @spec on protocol, defdelegate, recursive protocol dispatch,
#             Code.ensure_loaded? conditional implementation
defprotocol Renderable do
  @moduledoc """
  Protocol for rendering values to a display format.
  Inspired by Phoenix.HTML.Safe and Jason.Encoder.
  """

  @type opts :: keyword

  @fallback_to_any true

  @doc """
  Renders the value to iodata.
  """
  @spec render(t, opts) :: iodata
  def render(value, opts \\ [])
end

defimpl Renderable, for: Atom do
  def render(nil, _opts), do: ""
  def render(true, _opts), do: "true"
  def render(false, _opts), do: "false"
  def render(atom, _opts), do: Atom.to_string(atom)
end

defimpl Renderable, for: BitString do
  def render(binary, opts) when is_binary(binary) do
    if Keyword.get(opts, :escape, false) do
      escape_html(binary)
    else
      binary
    end
  end

  def render(bitstring, _opts) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: bitstring,
      description: "cannot render a bitstring"
  end

  defp escape_html(binary), do: do_escape(binary, [])

  defp do_escape(<<>>, acc), do: Enum.reverse(acc)
  defp do_escape(<<?<, rest::binary>>, acc), do: do_escape(rest, ["&lt;" | acc])
  defp do_escape(<<?>, rest::binary>>, acc), do: do_escape(rest, ["&gt;" | acc])
  defp do_escape(<<?&, rest::binary>>, acc), do: do_escape(rest, ["&amp;" | acc])
  defp do_escape(<<c, rest::binary>>, acc), do: do_escape(rest, [<<c>> | acc])
end

defimpl Renderable, for: Integer do
  defdelegate render(data, opts \\ []), to: Integer, as: :to_string
end

defimpl Renderable, for: Float do
  def render(float, opts) do
    decimals = Keyword.get(opts, :decimals, 2)
    :erlang.float_to_binary(float, decimals: decimals)
  end
end

defimpl Renderable, for: List do
  def render(list, opts) do
    separator = Keyword.get(opts, :separator, ", ")

    list
    |> Enum.map(&Renderable.render(&1, opts))
    |> Enum.intersperse(separator)
  end
end

defimpl Renderable, for: Map do
  def render(map, opts) do
    style = Keyword.get(opts, :map_style, :inline)

    pairs =
      Enum.map(map, fn {k, v} ->
        key = Renderable.render(k, opts)
        value = Renderable.render(v, opts)
        [key, ": ", value]
      end)

    case style do
      :inline ->
        ["%{", Enum.intersperse(pairs, ", "), "}"]

      :multiline ->
        lines = Enum.map(pairs, &["  ", &1, "\n"])
        ["%{\n", lines, "}"]
    end
  end
end

defimpl Renderable, for: Tuple do
  def render(tuple, opts) do
    elements =
      tuple
      |> Tuple.to_list()
      |> Enum.map(&Renderable.render(&1, opts))
      |> Enum.intersperse(", ")

    ["{", elements, "}"]
  end
end

defimpl Renderable, for: Date do
  defdelegate render(data, opts \\ []), to: Date, as: :to_iso8601
end

defimpl Renderable, for: Time do
  defdelegate render(data, opts \\ []), to: Time, as: :to_iso8601
end

defimpl Renderable, for: DateTime do
  def render(data, _opts), do: DateTime.to_iso8601(data)
end

defimpl Renderable, for: NaiveDateTime do
  def render(data, _opts), do: NaiveDateTime.to_iso8601(data)
end

defimpl Renderable, for: Any do
  def render(value, _opts) do
    inspect(value)
  end
end
