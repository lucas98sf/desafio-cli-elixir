defmodule DesafioCli.DatabaseTest do
  use ExUnit.Case, async: true
  alias DesafioCli.Database

  setup do
    {:ok, pid} = Database.start_link()
    %{pid: pid}
  end

  describe "begin/1" do
    test "starts a new transaction", %{pid: pid} do
      assert {:ok, 1} = Database.begin(pid)
      assert {:ok, 2} = Database.begin(pid)
    end
  end

  describe "rollback/1" do
    test "rolls back the last transaction", %{pid: pid} do
      Database.begin(pid)
      assert {:ok, 0} = Database.rollback(pid)
    end

    test "returns error when no transaction is in progress", %{pid: pid} do
      assert {:error, "No transaction in progress"} = Database.rollback(pid)
    end
  end

  describe "commit/1" do
    test "commits the last transaction", %{pid: pid} do
      Database.begin(pid)
      assert {:ok, 0} = Database.commit(pid)
    end

    test "merges nested transactions", %{pid: pid} do
      Database.begin(pid)
      Database.set(pid, "x", 1)
      Database.begin(pid)
      Database.set(pid, "x", 2)
      assert {:ok, 1} = Database.commit(pid)
      assert {:ok, 2} = Database.get(pid, "x")
    end

    test "returns error when no transaction is in progress", %{pid: pid} do
      assert {:error, "No transaction in progress"} = Database.commit(pid)
    end
  end

  describe "get/2" do
    test "retrieves a value", %{pid: pid} do
      Database.set(pid, "x", 42)
      assert {:ok, 42} = Database.get(pid, "x")
    end

    test "returns NIL for non-existent key", %{pid: pid} do
      assert {:ok, "NIL"} = Database.get(pid, "nonexistent")
    end

    test "retrieves value from ongoing transaction", %{pid: pid} do
      Database.begin(pid)
      Database.set(pid, "x", 42)
      assert {:ok, 42} = Database.get(pid, "x")
    end
  end

  describe "set/3" do
    test "sets a value", %{pid: pid} do
      assert {:ok, "FALSE 42"} = Database.set(pid, "x", 42)
      assert {:ok, 42} = Database.get(pid, "x")
    end

    test "overwrites an existing value", %{pid: pid} do
      Database.set(pid, "x", 42)
      assert {:ok, "TRUE 43"} = Database.set(pid, "x", 43)
      assert {:ok, 43} = Database.get(pid, "x")
    end

    test "sets a value in ongoing transaction", %{pid: pid} do
      Database.begin(pid)
      Database.set(pid, "x", 42)
      Database.rollback(pid)
      assert {:ok, "NIL"} = Database.get(pid, "x")
    end
  end
end

defmodule DesafioCli.CLITest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  alias DesafioCli.Database

  describe "handle_command/2" do
    setup do
      {:ok, pid} = Database.start_link()
      %{pid: pid}
    end

    test "BEGIN command", %{pid: pid} do
      assert {:ok, 1} = DesafioCli.handle_command(["BEGIN"], pid)
    end

    test "ROLLBACK command", %{pid: pid} do
      DesafioCli.handle_command(["BEGIN"], pid)
      assert {:ok, 0} = DesafioCli.handle_command(["ROLLBACK"], pid)
    end

    test "COMMIT command", %{pid: pid} do
      DesafioCli.handle_command(["BEGIN"], pid)
      assert {:ok, 0} = DesafioCli.handle_command(["COMMIT"], pid)
    end

    test "GET command", %{pid: pid} do
      DesafioCli.handle_command(["SET", "x", "42"], pid)
      assert {:ok, 42} = DesafioCli.handle_command(["GET", "x"], pid)
    end

    test "SET command", %{pid: pid} do
      assert {:ok, "FALSE 42"} = DesafioCli.handle_command(["SET", "x", "42"], pid)
    end

    test "Invalid command", %{pid: pid} do
      assert {:error, "No command INVALID"} = DesafioCli.handle_command(["INVALID"], pid)
    end
  end

  describe "main/1" do
    test "runs the CLI loop" do
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
