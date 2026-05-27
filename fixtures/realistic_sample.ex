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
end
