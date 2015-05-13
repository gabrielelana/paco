defmodule Paco.Parser.SeqTest do
  use ExUnit.Case, async: true

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
    assert parse(seq([string("a"), string("b")]), "bb") == {:error,
      """
      Failed to match seq([string(a), string(b)]) at 1:1, because it failed to match string(a) at 1:1
      """
    }
  end

  test "fail to parse because of the last parser" do
    assert parse(seq([string("a"), string("b")]), "aa") == {:error,
      """
      Failed to match seq([string(a), string(b)]) at 1:1, because it failed to match string(b) at 1:2
      """
    }
  end

  test "fail to parse for end of input" do
    assert parse(seq([string("aaa"), string("bbb")]), "a") == {:error,
      """
      Failed to match seq([string(aaa), string(bbb)]) at 1:1, because it failed to match string(aaa) at 1:1
      """
    }
  end
end
