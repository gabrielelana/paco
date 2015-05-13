defmodule Paco.Parser.StringTest do
  use ExUnit.Case, async: true

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
    assert parse(string("aaa"), "bbb") == {:error,
      """
      Failed to match string(aaa) at 1:1
      """
    }
  end

  test "skip doesn't influece failures" do
    assert parse(skip(string("aaa")), "bbb") == {:error,
      """
      Failed to match string(aaa) at 1:1
      """
    }
  end

  test "fail to parse empty string" do
    assert parse(string("aaa"), "") == {:error,
      """
      Failed to match string(aaa) at 1:1
      """
    }
  end

  test "increment indexes for a match" do
    input = Paco.Input.from("aaa")
    parser = string("aaa")
    success = parser.parse.(input, parser)
    assert success.from == {0, 1, 1}
    assert success.to == {2, 1, 3}
    assert success.at == {3, 1, 4}
    assert success.tail == ""
  end

  test "increment indexes for a match with newlines" do
    input = Paco.Input.from("a\na\na\nbbb")
    parser = string("a\na\na\n")
    success = parser.parse.(input, parser)
    assert success.from == {0, 1, 1}
    assert success.to == {5, 3, 2}
    assert success.at == {6, 4, 1}
    assert success.tail == "bbb"
  end

  test "increment indexes for a single character match" do
    input = Paco.Input.from("aaa")
    parser = string("a")
    success = parser.parse.(input, parser)
    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
    assert success.at == {1, 1, 2}
    assert success.tail == "aa"
  end

  test "increment indexes for an empty match" do
    input = Paco.Input.from("aaa")
    parser = string("")
    success = parser.parse.(input, parser)
    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
    assert success.at == {0, 1, 1}
    assert success.tail == "aaa"
  end
end
