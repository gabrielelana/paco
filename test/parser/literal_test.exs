defmodule Paco.Parser.LiteralTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "parse literal" do
    assert parse(literal("aaa"), "aaa") == {:ok, "aaa"}
  end

  test "parse multibyte literal" do
    assert parse(literal("あいうえお"), "あいうえお") == {:ok, "あいうえお"}
  end

  test "parse empty literal" do
    assert parse(literal(""), "") == {:ok, ""}
  end

  test "describe" do
    assert describe(literal("a")) == "literal(a)"
    assert describe(literal("\n")) == "literal(\\n)"
  end

  test "sigil" do
    assert %Paco.Parser{name: "literal", combine: "a"} = ~l"a"
    assert %Paco.Parser{name: "literal", combine: "a2"} = ~l"a#{1+1}"
  end

  test "skipped parsers should be removed from result" do
    assert parse(skip(literal("a")), "a") == {:ok, []}
  end

  test "fail to parse a literal" do
    assert parse(literal("aaa"), "bbb") == {:error,
      """
      Failed to match literal(aaa) at 1:1
      """
    }
  end

  test "skip doesn't influece failures" do
    assert parse(skip(literal("aaa")), "bbb") == {:error,
      """
      Failed to match literal(aaa) at 1:1
      """
    }
  end

  test "fail to parse empty literal" do
    assert parse(literal("aaa"), "") == {:error,
      """
      Failed to match literal(aaa) at 1:1
      """
    }
  end

  test "notify events on success" do
    assert Helper.events_notified_by(literal("aaa"), "aaa") == [
      {:loaded, "aaa"},
      {:started, "literal(aaa)"},
      {:matched, {0, 1, 1}, {2, 1, 3}, {3, 1, 4}},
    ]
  end

  test "notify events on failure" do
    assert Helper.events_notified_by(literal("bbb"), "aaa") == [
      {:loaded, "aaa"},
      {:started, "literal(bbb)"},
      {:failed, {0, 1, 1}},
    ]
  end

  test "increment indexes for a match" do
    parser = literal("aaa")
    success = parser.parse.(Paco.State.from("aaa"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {2, 1, 3}
    assert success.at == {3, 1, 4}
    assert success.tail == ""
  end

  test "increment indexes for a match with newlines" do
    parser = literal("a\na\na\n")
    success = parser.parse.(Paco.State.from("a\na\na\nbbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {5, 3, 2}
    assert success.at == {6, 4, 1}
    assert success.tail == "bbb"
  end

  test "increment indexes for a single character match" do
    parser = literal("a")
    success = parser.parse.(Paco.State.from("aaa"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
    assert success.at == {1, 1, 2}
    assert success.tail == "aa"
  end

  test "increment indexes for an empty match" do
    parser = literal("")
    success = parser.parse.(Paco.State.from("aaa"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
    assert success.at == {0, 1, 1}
    assert success.tail == "aaa"
  end
end
