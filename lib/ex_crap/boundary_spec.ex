defmodule ExCrap.Mix.BoundarySpec do
  @moduledoc false

  @snapshot_path "priv/boundary_spec.txt"
  @approval_phrase "approve boundary spec change"

  def snapshot_path do
    Process.get({__MODULE__, :snapshot_path}, @snapshot_path)
  end

  def approval_phrase, do: @approval_phrase

  def current_spec do
    case Process.get({__MODULE__, :current_spec}) do
      nil -> capture_boundary_spec()
      {:ok, _output} = result -> result
      {:error, _reason} = result -> result
      spec -> {:ok, spec}
    end
  end

  def check_snapshot(current, path \\ snapshot_path())
      when is_binary(current) and is_binary(path) do
    case File.read(path) do
      {:ok, ^current} -> :ok
      {:ok, expected} -> {:error, {:changed, diff(expected, current)}}
      {:error, :enoent} -> {:error, {:missing_snapshot, path}}
      {:error, reason} -> {:error, {:snapshot_unreadable, path, reason}}
    end
  end

  def write_snapshot(current, path \\ snapshot_path())
      when is_binary(current) and is_binary(path) do
    path
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write(path, current)
  end

  def interactive? do
    Process.get({__MODULE__, :interactive?}, stdin_tty?())
  end

  def read_confirmation do
    case Process.get({__MODULE__, :confirmation}) do
      nil -> IO.gets("Type #{inspect(@approval_phrase)} to approve: ")
      confirmation -> confirmation
    end
  end

  def diff(expected, current) when is_binary(expected) and is_binary(current) do
    (["--- priv/boundary_spec.txt", "+++ current boundary spec"] ++ diff_lines(expected, current))
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  defp diff_lines(expected, current) do
    expected_lines = diff_input_lines(expected)
    current_lines = diff_input_lines(current)

    if expected_lines == current_lines do
      []
    else
      ["@@ boundary spec @@"] ++
        Enum.map(expected_lines, &"-#{&1}") ++
        Enum.map(current_lines, &"+#{&1}")
    end
  end

  defp diff_input_lines(""), do: []

  defp diff_input_lines(output) do
    lines = String.split(output, "\n", trim: false)

    if String.ends_with?(output, "\n") do
      List.delete_at(lines, -1)
    else
      lines
    end
  end

  defp capture_boundary_spec do
    env = [{"MIX_ENV", to_string(Mix.env())}]

    case System.cmd("mix", ["boundary.spec"], env: env, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, status} -> {:error, {:boundary_spec_failed, status, output}}
    end
  end

  defp stdin_tty? do
    opts = Process.get({__MODULE__, :stdio_opts}) || :io.getopts(:standard_io)

    Keyword.get(opts, :stdin) == true and Keyword.get(opts, :terminal) == true
  rescue
    _exception -> false
  end
end
