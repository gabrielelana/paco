defmodule Paco.Parser.OneOfTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse one of the parsers" do
    assert parse(one_of([string("a"), string("b"), string("c")]), "a") == {:ok, "a"}
    assert parse(one_of([string("a"), string("b"), string("c")]), "b") == {:ok, "b"}
    assert parse(one_of([string("a"), string("b"), string("c")]), "c") == {:ok, "c"}
  end

  test "doesn't need to consume all the input" do
    assert parse(one_of([string("a"), string("b"), string("c")]), "abc") == {:ok, "a"}
  end

  test "with no parsers" do
    assert_raise ArgumentError, fn -> one_of([]) end
  end

  test "describe" do
    assert describe(one_of([string("a"), string("b")])) == "one_of([string(a), string(b)])"
  end

  test "skipped parsers should be removed from result" do
    assert parse(one_of([string("a"), skip(string("b"))]), "a") == {:ok, "a"}
    assert parse(one_of([string("a"), skip(string("b"))]), "b") == {:ok, []}
  end

  test "fail to parse" do
    assert parse(one_of([string("a"), string("b")]), "c") == {:error,
      """
      Failed to match one_of([string(a), string(b)]) at 1:1
      """
    }
  end

  test "one parser optimization, one_of is removed" do
    assert parse(one_of([string("a")]), "a") == {:ok, "a"}
    assert parse(one_of([string("a")]), "c") == {:error,
      """
      Failed to match string(a) at 1:1
      """
    }
  end
end
