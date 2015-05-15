defmodule Paco.Parser.SequenceOfTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "parse sequence of parsers" do
    assert parse(sequence_of([literal("a"), literal("b")]), "ab") == {:ok, ["a", "b"]}
    assert parse(sequence_of([literal("a")]), "a") == {:ok, ["a"]}
  end

  test "with no parsers" do
    assert_raise ArgumentError, fn -> sequence_of([]) end
  end

  test "describe" do
    assert describe(sequence_of([literal("a"), literal("b")])) == "sequence_of#3([literal#1, literal#2])"
  end

  test "skipped parsers should be removed from result" do
    assert parse(sequence_of([literal("a"), skip(literal("b")), literal("c")]), "abc") == {:ok, ["a", "c"]}
    assert parse(sequence_of([skip(literal("a"))]), "a") == {:ok, []}
  end

  test "fail to parse because of the first parser" do
    assert parse(sequence_of([literal("a"), literal("b")]), "bb") == {:error,
      """
      Failed to match sequence_of#3([literal#1, literal#2]) at 1:1, because it failed to match literal#1("a") at 1:1
      """
    }
  end

  test "fail to parse because of the last parser" do
    assert parse(sequence_of([literal("a"), literal("b")]), "aa") == {:error,
      """
      Failed to match sequence_of#3([literal#1, literal#2]) at 1:1, because it failed to match literal#2("b") at 1:2
      """
    }
  end

  test "fail to parse for end of input" do
    assert parse(sequence_of([literal("aaa"), literal("bbb")]), "a") == {:error,
      """
      Failed to match sequence_of#3([literal#1, literal#2]) at 1:1, because it failed to match literal#1("aaa") at 1:1
      """
    }
  end

  test "notify events on success" do
    assert Helper.events_notified_by(sequence_of([literal("a"), literal("b")]), "ab") == [
      {:loaded, "ab"},
      {:started, "sequence_of#3([literal#1, literal#2])"},
      {:started, ~s|literal#1("a")|},
      {:matched, {0, 1, 1}, {0, 1, 1}, {1, 1, 2}},
      {:started, ~s|literal#2("b")|},
      {:matched, {1, 1, 2}, {1, 1, 2}, {2, 1, 3}},
      {:matched, {0, 1, 1}, {1, 1, 2}, {2, 1, 3}},
    ]
  end

  test "notify events on failure" do
    assert Helper.events_notified_by(sequence_of([literal("a"), literal("b")]), "cc") == [
      {:loaded, "cc"},
      {:started, "sequence_of#3([literal#1, literal#2])"},
      {:started, ~s|literal#1("a")|},
      {:failed, {0, 1, 1}},
      {:failed, {0, 1, 1}},
    ]
    assert Helper.events_notified_by(sequence_of([literal("a"), literal("b")]), "ac") == [
      {:loaded, "ac"},
      {:started, "sequence_of#6([literal#4, literal#5])"},
      {:started, ~s|literal#4("a")|},
      {:matched, {0, 1, 1}, {0, 1, 1}, {1, 1, 2}},
      {:started, ~s|literal#5("b")|},
      {:failed, {1, 1, 2}},
      {:failed, {0, 1, 1}},
    ]
  end
end
