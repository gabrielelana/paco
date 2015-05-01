defmodule Paco.Parser.String.Test do
  use ExUnit.Case

  import Paco
  import Paco.Parser

  test "parse string" do
    assert parse(string("aaa"), "aaa") == {:ok, "aaa"}
  end

  test "parse multibyte string" do
    assert parse(string("あいうえお"), "あいうえお") == {:ok, "あいうえお"}
  end

  test "parse empty string" do
    assert parse(string(""), "") == {:ok, ""}
  end

  test "fail to parse a string" do
    {:error, failure} = parse(string("aaa"), "bbb")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match string(aaa) at 1:1
      """
  end

  test "fail to parse a long string" do
    {:error, failure} = parse(string(String.duplicate("a", 1000)), "bbb")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match string(aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa...) at 1:1
      """
  end
end
