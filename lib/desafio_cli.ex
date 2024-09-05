defmodule DesafioCli do
  @moduledoc """
  Ponto de entrada para a CLI.
  """

  alias DesafioCli.Database

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

defmodule DesafioCli.Database do
  @moduledoc """
  Controla o estado da database e as transações
  """

  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, %{database: %{}, transactions: []})
  end

  def begin(pid) do
    GenServer.call(pid, :begin)
  end

  def rollback(pid) do
    GenServer.call(pid, :rollback)
  end

  def commit(pid) do
    GenServer.call(pid, :commit)
  end

  def get(pid, key) do
    GenServer.call(pid, {:get, key})
  end

  def set(pid, key, value) do
    GenServer.call(pid, {:set, key, value})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call(:begin, _from, state) do
    new_state = Map.put(state, :transactions, state.transactions ++ [%{}])
    {:reply, {:ok, length(new_state.transactions)}, new_state}
  end

  @impl true
  def handle_call(:rollback, _from, state) do
    case length(state.transactions) do
      0 ->
        {:reply, {:error, "No transaction in progress"}, state}

      _ ->
        new_state = Map.put(state, :transactions, List.delete_at(state.transactions, -1))
        {:reply, {:ok, length(new_state.transactions)}, new_state}
    end
  end

  @impl true
  def handle_call(:commit, _from, state) do
    case length(state.transactions) do
      0 ->
        {:reply, {:error, "No transaction in progress"}, state}

      1 ->
        new_state = %{
          transactions: [],
          database: Map.merge(state.database, List.first(state.transactions))
        }

        {:reply, {:ok, 0}, new_state}

      _ ->
        last_transaction = List.last(state.transactions)
        remaining_transactions = List.delete_at(state.transactions, -1)

        new_state =
          Map.put(
            state,
            :transactions,
            List.delete_at(remaining_transactions, -1) ++
              [Map.merge(List.last(remaining_transactions), last_transaction)]
          )

        {:reply, {:ok, length(new_state.transactions)}, new_state}
    end
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    value = get_value(state, key)
    {:reply, {:ok, value}, state}
  end

  @impl true
  def handle_call({:set, key, value}, _from, state) do
    {new_state, exists} = set_value(state, key, value)
    {:reply, {:ok, "#{exists} #{value}"}, new_state}
  end

  defp get_value(state, key) do
    merged_state = get_merged_state(state)
    Map.get(merged_state, key, "NIL")
  end

  defp set_value(state, key, value) do
    merged_state = get_merged_state(state)
    exists = if Map.has_key?(merged_state, key), do: "TRUE", else: "FALSE"

    new_state =
      if Enum.empty?(state.transactions) do
        Map.put(state, :database, Map.put(state.database, key, value))
      else
        last_transaction = List.last(state.transactions)

        Map.put(
          state,
          :transactions,
          List.delete_at(state.transactions, -1) ++ [Map.put(last_transaction, key, value)]
        )
      end

    {new_state, exists}
  end

  defp get_merged_state(state) do
    transactions_merged =
      state.transactions
      |> Enum.reduce(%{}, &Map.merge(&2, &1))

    Map.merge(state.database, transactions_merged)
  end
end
