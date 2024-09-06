defmodule Database do
  @moduledoc """
  Controla o estado da database e as transações, com persistência de dados.
  """

  use GenServer

  @db_file "db_state.dat"

  def start_link do
    GenServer.start_link(__MODULE__, load_state_from_file())
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

  def rollback_except_first(pid) do
    GenServer.call(pid, :rollback_except_first)
  end

  def commit_first(pid) do
    GenServer.call(pid, :commit_first)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call(:rollback_except_first, _from, state) do
    case length(state.transactions) do
      0 ->
        {:reply, {:error, "No transactions to rollback"}, state}

      1 ->
        {:reply, {:ok, state}, state}

      _ ->
        first_transaction = List.first(state.transactions)
        new_state = Map.put(state, :transactions, [first_transaction])
        {:reply, {:ok, new_state}, new_state}
    end
  end

  @impl true
  def handle_call(:commit_first, _from, state) do
    case state.transactions do
      [first_transaction | _] ->
        new_state = %{
          transactions: [],
          database: Map.merge(state.database, first_transaction)
        }

        save_state_to_file(new_state)
        {:reply, {:ok, new_state}, new_state}

      _ ->
        {:reply, {:error, "No transaction to commit"}, state}
    end
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

        save_state_to_file(new_state)
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

        save_state_to_file(new_state)
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
    save_state_to_file(new_state)
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

  defp save_state_to_file(state) do
    serialized_state = :erlang.term_to_binary(state)
    File.write!(@db_file, serialized_state)
  end

  defp load_state_from_file do
    case File.read(@db_file) do
      {:ok, content} -> :erlang.binary_to_term(content)
      {:error, _reason} -> %{database: %{}, transactions: []}
    end
  end
end
