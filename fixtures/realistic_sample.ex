defmodule Realistic.Sample do
  @moduledoc "A fixture shaped like an ordinary Elixir source file."

  alias String, as: Text

  def normalize(value) when is_binary(value) do
    value
    |> Text.trim()
    |> Text.downcase()
  end

  def classify(value) do
    case normalize(value) do
      "" -> :blank
      "admin" -> :privileged
      _other -> :regular
    end
  end

  def visible?(user) do
    if user.active and not user.deleted do
      true
    else
      false
    end
  end

  defp fallback(value) do
    cond do
      value == nil -> :missing
      value == false -> :disabled
      true -> :present
    end
  end

  def fetch(key, opts) when is_atom(key) and is_list(opts) do
    timeout = Keyword.get(opts, :timeout, 5000)

    receive do
      {^key, value} -> {:ok, value}
      {:error, reason} -> {:error, reason}
    after
      timeout -> :timeout
    end
  end

  def process(items) do
    for item <- items, item.active?, item.valid? do
      item.name
    end
  end

  def load(id, source) do
    with {:ok, raw} <- source.fetch(id),
         {:ok, parsed} <- parse(raw) do
      {:ok, parsed}
    else
      :error -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defmacro assert_valid(expr) do
    if expr, do: :ok, else: raise("assertion failed")
  end
end
