defmodule ExCrap.Coverage do
  use Boundary

  @moduledoc """
  Imports Erlang/Mix coverdata and exposes function coverage percentages.
  """

  @doc """
  Imports an exported `.coverdata` file and returns coverage by `{module, function, arity}`.
  """
  def from_coverdata(path) when is_binary(path) do
    if File.regular?(path) do
      with :ok <- ensure_cover_started(),
           :ok <- :cover.import(String.to_charlist(path)),
           modules when is_list(modules) <- analysis_modules() do
        {:ok, coverage_for_modules(modules)}
      else
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, {:coverdata_unreadable, path}}
    end
  end

  @doc """
  Converts Erlang `:cover` function rows into percentage coverage.
  """
  def from_function_rows(rows) when is_list(rows) do
    Map.new(rows, fn {{module, function, arity}, {covered, not_covered}} ->
      total = covered + not_covered
      percent = if total == 0, do: 0.0, else: covered / total * 100
      {normalize_key(module, function, arity), percent}
    end)
  end

  defp normalize_key(module, function, arity) do
    case Atom.to_string(function) do
      "MACRO-" <> name -> {module, String.to_atom(name), arity - 1}
      _other -> {module, function, arity}
    end
  end

  defp ensure_cover_started do
    case :cover.start() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      :ok -> :ok
    end
  end

  defp analysis_modules do
    imported_modules = :cover.imported_modules()

    case imported_modules do
      modules when is_list(modules) and modules != [] -> modules
      _other -> :cover.modules()
    end
  end

  defp coverage_for_modules(modules) do
    without_cover_output(fn ->
      Enum.flat_map(modules, fn module ->
        case :cover.analyse(module, :coverage, :function) do
          {:ok, rows} -> rows
          {:error, _reason} -> []
        end
      end)
    end)
    |> from_function_rows()
  end

  defp without_cover_output(fun) do
    group_leader = Process.group_leader()
    cover_pid = cover_pid()
    cover_group_leader = if cover_pid, do: Process.info(cover_pid, :group_leader) |> elem(1)
    {:ok, io} = StringIO.open("")

    try do
      Process.group_leader(self(), io)
      if cover_pid, do: Process.group_leader(cover_pid, io)
      fun.()
    after
      Process.group_leader(self(), group_leader)
      if cover_pid, do: Process.group_leader(cover_pid, cover_group_leader)
    end
  end

  defp cover_pid do
    case :cover.start() do
      {:error, {:already_started, pid}} -> pid
      {:ok, pid} -> pid
      _other -> nil
    end
  end
end
