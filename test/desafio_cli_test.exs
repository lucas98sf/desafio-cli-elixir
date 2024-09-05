defmodule DesafioCliTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  @file_path "db_state.dat"

  setup do
    # Ensure the state file is removed before each test
    on_exit(fn ->
      File.rm(@file_path)
    end)

    # Start the Database GenServer manually
    {:ok, pid} = Database.start_link()
    {:ok, pid: pid}
  end

  describe "GenServer operations" do
    test "BEGIN command", %{pid: pid} do
      assert {:ok, 1} = DesafioCli.handle_command(["BEGIN"], pid)
    end

    test "ROLLBACK command", %{pid: pid} do
      DesafioCli.handle_command(["BEGIN"], pid)
      assert {:ok, 0} = DesafioCli.handle_command(["ROLLBACK"], pid)
    end

    test "ROLLBACK command with no transaction", %{pid: pid} do
      assert {:error, "No transaction in progress"} = DesafioCli.handle_command(["ROLLBACK"], pid)
    end

    test "COMMIT command", %{pid: pid} do
      DesafioCli.handle_command(["BEGIN"], pid)
      DesafioCli.handle_command(["SET", "x", "1"], pid)
      assert {:ok, 0} = DesafioCli.handle_command(["COMMIT"], pid)
    end

    test "COMMIT command with no transaction", %{pid: pid} do
      assert {:error, "No transaction in progress"} = DesafioCli.handle_command(["COMMIT"], pid)
    end

    test "GET command", %{pid: pid} do
      DesafioCli.handle_command(["SET", "x", "1"], pid)
      assert {:ok, 1} = DesafioCli.handle_command(["GET", "x"], pid)
    end

    test "GET command for non-existent key", %{pid: pid} do
      assert {:ok, "NIL"} = DesafioCli.handle_command(["GET", "x"], pid)
    end

    test "SET command", %{pid: pid} do
      assert {:ok, "FALSE 1"} = DesafioCli.handle_command(["SET", "x", "1"], pid)
    end

    test "SET command in transaction", %{pid: pid} do
      DesafioCli.handle_command(["BEGIN"], pid)
      assert {:ok, "FALSE 1"} = DesafioCli.handle_command(["SET", "x", "1"], pid)
    end
  end

  describe "Persistence" do
    test "saves and loads state", %{pid: pid} do
      DesafioCli.handle_command(["SET", "x", "1"], pid)
      DesafioCli.handle_command(["SET", "y", "2"], pid)

      # Stop the Database GenServer to simulate shutting down the application
      :ok = GenServer.stop(pid)

      # Start it again to simulate restarting the application
      {:ok, new_pid} = Database.start_link()

      # Ensure the state persists after restarting
      assert {:ok, 1} = DesafioCli.handle_command(["GET", "x"], new_pid)
      assert {:ok, 2} = DesafioCli.handle_command(["GET", "y"], new_pid)
    end

    test "state is reset if no persistence file exists", %{pid: pid} do
      DesafioCli.handle_command(["SET", "x", "1"], pid)
      DesafioCli.handle_command(["SET", "y", "2"], pid)

      # Remove the persistence file to simulate starting without previous state
      File.rm!(@file_path)

      # Stop and restart the Database GenServer
      :ok = GenServer.stop(pid)
      {:ok, new_pid} = Database.start_link()

      # After the restart, the state should be empty
      assert {:ok, "NIL"} = DesafioCli.handle_command(["GET", "x"], new_pid)
      assert {:ok, "NIL"} = DesafioCli.handle_command(["GET", "y"], new_pid)
    end
  end

  describe "CLI interface" do
    test "runs the CLI loop", %{pid: _pid} do
      input = """
      BEGIN
      SET x 42
      GET x
      COMMIT
      GET x
      QUIT
      """

      expected_output = """
      > 1
      > FALSE 42
      > 42
      > 0
      > 42
      > ERR No command QUIT
      """

      assert capture_io([input: input, capture_prompt: false], fn ->
               DesafioCli.main([])
             end) =~ expected_output
    end
  end
end
