defmodule Paco.Parser.String.Test do
  use ExUnit.Case

  import Paco
  import Paco.Parser

  test "string" do
    assert parse(string("aaa"), "aaa") == {:ok, "aaa"}
  end

  test "multibyte string" do
    assert parse(string("あいうえお"), "あいうえお") == {:ok, "あいうえお"}
  end

  test "empty string" do
    assert parse(string(""), "") == {:ok, ""}
  end

  test "fail to match" do
    {:error, failure} = parse(string("aaa"), "bbb")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match string(aaa) at line: 1, column: 1
      """
  end

  test "fail to match a long string" do
    {:error, failure} = parse(string(String.duplicate("a", 1000)), "bbb")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match string(aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa...) at line: 1, column: 1
      """
  end
end
