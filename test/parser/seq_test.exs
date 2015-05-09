defmodule Paco.Parser.SeqTest do
  use ExUnit.Case

  import Paco
  import Paco.Parser

  test "parse seq of parsers" do
    assert parse(seq([string("a"), string("b")]), "ab") == {:ok, ["a", "b"]}
    assert parse(seq([string("a")]), "a") == {:ok, ["a"]}
  end

  test "with no parsers" do
    assert_raise ArgumentError, fn -> seq([]) end
  end

  test "describe" do
    assert describe(seq([string("a"), string("b")])) == "seq([string(a), string(b)])"
  end

  test "skipped parsers should be removed from result" do
    assert parse(seq([string("a"), skip(string("b")), string("c")]), "abc") == {:ok, ["a", "c"]}
    assert parse(seq([skip(string("a"))]), "a") == {:ok, []}
  end

  test "fail to parse because of the first parser" do
    {:error, failure} = parse(seq([string("a"), string("b")]), "bb")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match seq([string(a), string(b)]) at 1:1, because it failed to match string(a) at 1:1
      """
  end

  test "fail to parse because of the last parser" do
    {:error, failure} = parse(seq([string("a"), string("b")]), "aa")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match seq([string(a), string(b)]) at 1:1, because it failed to match string(b) at 1:2
      """
  end

  test "fail to parse for end of input" do
    {:error, failure} = parse(seq([string("aaa"), string("bbb")]), "a")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match seq([string(aaa), string(bbb)]) at 1:1, because it failed to match string(aaa) at 1:1
      """
  end

end
