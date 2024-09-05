defmodule DesafioCliTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  describe "handle_command/2" do
    test "BEGIN command" do
      state = %DesafioCli.State{}

      assert {{:ok, 1}, %DesafioCli.State{transactions: [%{}]}} =
               DesafioCli.handle_command(["BEGIN"], state)
    end

    test "ROLLBACK command" do
      state = %DesafioCli.State{transactions: [%{}]}

      assert {{:ok, 0}, %DesafioCli.State{transactions: []}} =
               DesafioCli.handle_command(["ROLLBACK"], state)
    end

    test "ROLLBACK command with no transaction" do
      state = %DesafioCli.State{}

      assert {{:error, "No transaction in progress"}, ^state} =
               DesafioCli.handle_command(["ROLLBACK"], state)
    end

    test "COMMIT command" do
      state = %DesafioCli.State{transactions: [%{"x" => 1}]}

      assert {{:ok, 0}, %DesafioCli.State{database: %{"x" => 1}, transactions: []}} =
               DesafioCli.handle_command(["COMMIT"], state)
    end

    test "COMMIT command with no transaction" do
      state = %DesafioCli.State{}

      assert {{:error, "No transaction in progress"}, ^state} =
               DesafioCli.handle_command(["COMMIT"], state)
    end

    test "GET command" do
      state = %DesafioCli.State{database: %{"x" => 1}}
      assert {{:ok, 1}, ^state} = DesafioCli.handle_command(["GET", "x"], state)
    end

    test "GET command for non-existent key" do
      state = %DesafioCli.State{}
      assert {{:ok, "NIL"}, ^state} = DesafioCli.handle_command(["GET", "x"], state)
    end

    test "SET command" do
      state = %DesafioCli.State{}

      assert {{:ok, "FALSE 1"}, %DesafioCli.State{database: %{"x" => "1"}}} =
               DesafioCli.handle_command(["SET", "x", "1"], state)
    end

    test "SET command in transaction" do
      state = %DesafioCli.State{transactions: [%{}]}

      assert {{:ok, "FALSE 1"}, %DesafioCli.State{transactions: [%{"x" => "1"}]}} =
               DesafioCli.handle_command(["SET", "x", "1"], state)
    end

    test "Invalid command" do
      state = %DesafioCli.State{}

      assert {{:error, "No command INVALID"}, ^state} =
               DesafioCli.handle_command(["INVALID"], state)
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
