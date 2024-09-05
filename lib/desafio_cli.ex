defmodule DesafioCli do
  @moduledoc """
  Ponto de entrada para a CLI.
  """

  defmodule State do
    defstruct database: %{}, transactions: []
  end

  @doc """
  A função main recebe os argumentos passados na linha de
  comando como lista de strings e executa a CLI.
  """
  def main(_args) do
    loop(%State{})
  end

  defp loop(state) do
    IO.write("> ")

    case IO.read(:line) do
      :eof ->
        :ok

      input ->
        {result, new_state} =
          input
          |> String.trim()
          |> String.split()
          |> handle_command(state)

        case result do
          {:ok, message} -> IO.puts(message)
          {:error, message} -> IO.puts("ERR #{message}")
        end

        loop(new_state)
    end
  end

  def handle_command(["BEGIN"], state) do
    new_state = %{state | transactions: [%{} | state.transactions]}
    {{:ok, length(new_state.transactions)}, new_state}
  end

  def handle_command(["ROLLBACK"], state) do
    case state.transactions do
      [] ->
        {{:error, "No transaction in progress"}, state}

      [_ | rest] ->
        new_state = %{state | transactions: rest}
        {{:ok, length(new_state.transactions)}, new_state}
    end
  end

  def handle_command(["COMMIT"], state) do
    case state.transactions do
      [] ->
        {{:error, "No transaction in progress"}, state}

      transactions ->
        merged = Enum.reduce(transactions, %{}, &Map.merge/2)
        new_state = %{state | database: Map.merge(state.database, merged), transactions: []}
        {{:ok, 0}, new_state}
    end
  end

  def handle_command(["GET", key], state) do
    value = get_value(state, key)
    {{:ok, value}, state}
  end

  def handle_command(["SET", key, value], state) do
    {new_state, exists} = set_value(state, key, value)
    {{:ok, "#{exists} #{value}"}, new_state}
  end

  def handle_command([command | _], state) do
    {{:error, "No command #{command}"}, state}
  end

  defp get_value(state, key) do
    merged_state = get_merged_state(state)
    Map.get(merged_state, key, "NIL")
  end

  defp set_value(state, key, value) do
    merged_state = get_merged_state(state)
    exists = if Map.has_key?(merged_state, key), do: "TRUE", else: "FALSE"

    new_state =
      case state.transactions do
        [] ->
          %{state | database: Map.put(state.database, key, value)}

        [current | rest] ->
          %{state | transactions: [Map.put(current, key, value) | rest]}
      end

    {new_state, exists}
  end

  defp get_merged_state(state) do
    Enum.reduce(state.transactions, state.database, &Map.merge/2)
  end
end
