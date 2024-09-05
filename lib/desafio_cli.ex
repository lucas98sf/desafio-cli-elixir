defmodule DesafioCli do
  @moduledoc """
  Ponto de entrada para a CLI.
  """

  @doc """
  A função main recebe os argumentos passados na linha de
  comando como lista de strings e executa a CLI.
  """
  def main(_args) do
    {:ok, pid} = Database.start_link()
    loop(pid)
  end

  defp loop(pid) do
    IO.write("> ")

    case IO.read(:line) do
      :eof ->
        :ok

      input ->
        result =
          input
          |> String.trim()
          |> StringUtils.split_with_quotes()
          |> handle_command(pid)

        case result do
          {:ok, message} -> IO.puts(message)
          {:error, message} -> IO.puts("ERR #{message}")
        end

        loop(pid)
    end
  end

  def handle_command([command | args], pid) do
    case String.upcase(command) do
      "BEGIN" -> handle_begin(args, pid)
      "ROLLBACK" -> handle_rollback(args, pid)
      "COMMIT" -> handle_commit(args, pid)
      "GET" -> handle_get(args, pid)
      "SET" -> handle_set(args, pid)
      _ -> {:error, "No command #{command}"}
    end
  end

  defp handle_begin([], pid), do: Database.begin(pid)
  defp handle_begin(_, _pid), do: {:error, "BEGIN - Syntax error"}

  defp handle_rollback([], pid), do: Database.rollback(pid)
  defp handle_rollback(_, _pid), do: {:error, "ROLLBACK - Syntax error"}

  defp handle_commit([], pid), do: Database.commit(pid)
  defp handle_commit(_, _pid), do: {:error, "COMMIT - Syntax error"}

  defp handle_get([key], pid), do: Database.get(pid, key)
  defp handle_get(_, _pid), do: {:error, "GET <key> - Syntax error"}

  defp handle_set([key, value], pid) do
    parsed_value = parse_value(value)
    Database.set(pid, key, parsed_value)
  end

  defp handle_set(_, _pid), do: {:error, "SET <key> <value> - Syntax error"}

  defp parse_value(arg) do
    cond do
      String.match?(arg, ~r/^-?\d+$/) -> String.to_integer(arg)
      String.match?(arg, ~r/^TRUE$/i) -> true
      String.match?(arg, ~r/^FALSE$/i) -> false
      true -> arg
    end
  end
end
