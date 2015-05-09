defmodule Paco.Parser.StringTest do
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

  test "describe" do
    assert describe(string("a")) == "string(a)"
    assert describe(string("\n")) == "string(\\n)"
  end

  test "skipped parsers should be removed from result" do
    assert parse(skip(string("a")), "a") == {:ok, []}
  end

  test "fail to parse a string" do
    {:error, failure} = parse(string("aaa"), "bbb")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match string(aaa) at 1:1
      """
  end

  test "skip doesn't influece failures" do
    {:error, failure} = parse(skip(string("aaa")), "bbb")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match string(aaa) at 1:1
      """
  end

  test "fail to parse empty string" do
    {:error, failure} = parse(string("aaa"), "")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match string(aaa) at 1:1
      """
  end
end
