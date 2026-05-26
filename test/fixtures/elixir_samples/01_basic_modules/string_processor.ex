# Source: Inspired by jason/lib/jason.ex and jason/lib/formatter.ex
# Complexity: Moderate
# Constructs: multi-clause functions, pattern matching, guards, binary matching,
#             recursive functions, @type, @spec, pipeline operator
defmodule StringProcessor do
  @moduledoc """
  String processing utilities demonstrating multi-clause functions
  and pattern matching on binaries.
  """

  @type case_style :: :snake_case | :camel_case | :kebab_case | :title_case

  @type transform_opt ::
          {:style, case_style}
          | {:trim, boolean}
          | {:max_length, pos_integer | :infinity}

  @doc """
  Transforms a string according to the given options.
  """
  @spec transform(String.t(), [transform_opt]) :: String.t()
  def transform(input, opts \\ []) when is_binary(input) do
    input
    |> maybe_trim(Keyword.get(opts, :trim, false))
    |> maybe_restyle(Keyword.get(opts, :style))
    |> maybe_truncate(Keyword.get(opts, :max_length, :infinity))
  end

  @doc """
  Counts occurrences of a character in a binary string.
  """
  @spec count_char(String.t(), char) :: non_neg_integer
  def count_char(string, char) when is_binary(string) and is_integer(char) do
    do_count_char(string, char, 0)
  end

  defp do_count_char(<<>>, _char, acc), do: acc
  defp do_count_char(<<c, rest::binary>>, c, acc), do: do_count_char(rest, c, acc + 1)
  defp do_count_char(<<_, rest::binary>>, char, acc), do: do_count_char(rest, char, acc)

  @doc """
  Escapes special HTML characters in a string.
  """
  @spec html_escape(String.t()) :: String.t()
  def html_escape(string) when is_binary(string) do
    do_html_escape(string, [])
  end

  defp do_html_escape(<<>>, acc), do: acc |> Enum.reverse() |> IO.iodata_to_binary()
  defp do_html_escape(<<?<, rest::binary>>, acc), do: do_html_escape(rest, ["&lt;" | acc])
  defp do_html_escape(<<?>, rest::binary>>, acc), do: do_html_escape(rest, ["&gt;" | acc])
  defp do_html_escape(<<?&, rest::binary>>, acc), do: do_html_escape(rest, ["&amp;" | acc])
  defp do_html_escape(<<?", rest::binary>>, acc), do: do_html_escape(rest, ["&quot;" | acc])
  defp do_html_escape(<<c, rest::binary>>, acc), do: do_html_escape(rest, [<<c>> | acc])

  @doc """
  Validates that a string matches a basic pattern.
  """
  @spec valid_identifier?(String.t()) :: boolean
  def valid_identifier?(<<c, _rest::binary>>) when c in ?a..?z or c == ?_, do: true
  def valid_identifier?(<<c, _rest::binary>>) when c in ?A..?Z, do: true
  def valid_identifier?(_), do: false

  # Private helpers

  defp maybe_trim(input, true), do: String.trim(input)
  defp maybe_trim(input, false), do: input

  defp maybe_restyle(input, nil), do: input

  defp maybe_restyle(input, :snake_case) do
    input
    |> String.replace(~r/([A-Z])/, "_\\1")
    |> String.downcase()
    |> String.trim_leading("_")
  end

  defp maybe_restyle(input, :kebab_case) do
    input
    |> maybe_restyle(:snake_case)
    |> String.replace("_", "-")
  end

  defp maybe_restyle(input, :camel_case) do
    input
    |> String.split("_")
    |> Enum.map_join(&String.capitalize/1)
  end

  defp maybe_restyle(input, :title_case) do
    input
    |> String.split(~r/[\s_-]+/)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp maybe_truncate(input, :infinity), do: input

  defp maybe_truncate(input, max) when is_integer(max) and max > 0 do
    if String.length(input) > max do
      String.slice(input, 0, max) <> "..."
    else
      input
    end
  end
end
