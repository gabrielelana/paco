defmodule Paco.Parser.OneOfTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "parse one of the parsers" do
    assert parse(one_of([literal("a"), literal("b"), literal("c")]), "a") == {:ok, "a"}
    assert parse(one_of([literal("a"), literal("b"), literal("c")]), "b") == {:ok, "b"}
    assert parse(one_of([literal("a"), literal("b"), literal("c")]), "c") == {:ok, "c"}
  end

  test "doesn't need to consume all the text" do
    assert parse(one_of([literal("a"), literal("b"), literal("c")]), "abc") == {:ok, "a"}
  end

  test "with no parsers" do
    assert_raise ArgumentError, fn -> one_of([]) end
  end

  test "describe" do
    assert describe(one_of([literal("a"), literal("b")])) == "one_of#3([literal#1, literal#2])"
  end

  test "skipped parsers should be removed from result" do
    assert parse(one_of([literal("a"), skip(literal("b"))]), "a") == {:ok, "a"}
    assert parse(one_of([literal("a"), skip(literal("b"))]), "b") == {:ok, []}
  end

  test "fail to parse" do
    assert parse(one_of([literal("a"), literal("b")]), "c") == {:error,
      """
      Failed to match one_of#3([literal#1, literal#2]) at 1:1
      """
    }
  end

  test "one parser optimization, one_of is removed" do
    assert parse(one_of([literal("a")]), "a") == {:ok, "a"}
    assert parse(one_of([literal("a")]), "c") == {:error,
      """
      Failed to match literal#2("a") at 1:1
      """
    }
  end

  test "notify events on success" do
    assert Helper.events_notified_by(one_of([literal("a"), literal("b")]), "a") == [
      {:loaded, "a"},
      {:started, "one_of#3([literal#1, literal#2])"},
      {:started, ~s|literal#1("a")|},
      {:matched, {0, 1, 1}, {0, 1, 1}, {1, 1, 2}},
      {:matched, {0, 1, 1}, {0, 1, 1}, {1, 1, 2}},
    ]
    assert Helper.events_notified_by(one_of([literal("a"), literal("b")]), "b") == [
      {:loaded, "b"},
      {:started, "one_of#6([literal#4, literal#5])"},
      {:started, ~s|literal#4("a")|},
      {:failed, {0, 1, 1}},
      {:started, ~s|literal#5("b")|},
      {:matched, {0, 1, 1}, {0, 1, 1}, {1, 1, 2}},
      {:matched, {0, 1, 1}, {0, 1, 1}, {1, 1, 2}},
    ]
  end

  test "notify events on failure" do
    assert Helper.events_notified_by(one_of([literal("a"), literal("b")]), "c") == [
      {:loaded, "c"},
      {:started, "one_of#3([literal#1, literal#2])"},
      {:started, ~s|literal#1("a")|},
      {:failed, {0, 1, 1}},
      {:started, ~s|literal#2("b")|},
      {:failed, {0, 1, 1}},
      {:failed, {0, 1, 1}},
    ]
  end
end
