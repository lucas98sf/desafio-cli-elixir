defmodule StringUtilsTest do
  use ExUnit.Case

  describe "split_with_quotes/1" do
    test "splits unquoted words" do
      input = "one two three"
      expected_output = ["one", "two", "three"]
      assert StringUtils.split_with_quotes(input) == expected_output
    end

    test "splits quoted words with double quotes" do
      input = ~s(one "two words" three)
      expected_output = ["one", "two words", "three"]
      assert StringUtils.split_with_quotes(input) == expected_output
    end

    test "splits quoted words with single quotes" do
      input = "one 'two words' three"
      expected_output = ["one", "two words", "three"]
      assert StringUtils.split_with_quotes(input) == expected_output
    end

    test "splits mixed single and double quotes" do
      input = ~s(one 'two words' "three words")
      expected_output = ["one", "two words", "three words"]
      assert StringUtils.split_with_quotes(input) == expected_output
    end

    test "handles escaped quotes inside words" do
      input = ~s(one "two \\"escaped\\" words" three)
      expected_output = ["one", "two \"escaped\" words", "three"]
      assert StringUtils.split_with_quotes(input) == expected_output
    end

    test "handles escaped single quotes inside words" do
      input = "one 'two \\'escaped\\' words' three"
      expected_output = ["one", "two 'escaped' words", "three"]
      assert StringUtils.split_with_quotes(input) == expected_output
    end

    test "splits words with no spaces between quotes and other words" do
      input = "one'two words'\"three words\""
      expected_output = ["one", "two words", "three words"]
      assert StringUtils.split_with_quotes(input) == expected_output
    end

    test "handles empty string" do
      input = ""
      expected_output = []
      assert StringUtils.split_with_quotes(input) == expected_output
    end
  end
end
