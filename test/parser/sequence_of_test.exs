defmodule Paco.Parser.SequenceOfTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "parse sequence of parsers" do
    assert parse(sequence_of([lit("a"), lit("b")]), "ab") == {:ok, ["a", "b"]}
    assert parse(sequence_of([lit("a")]), "a") == {:ok, ["a"]}
  end

  test "with no parsers" do
    assert_raise ArgumentError, fn -> sequence_of([]) end
  end

  test "describe" do
    assert describe(sequence_of([lit("a"), lit("b")])) == "sequence_of#3([lit#1, lit#2])"
  end

  test "skipped parsers should be removed from result" do
    assert parse(sequence_of([lit("a"), skip(lit("b")), lit("c")]), "abc") == {:ok, ["a", "c"]}
    assert parse(sequence_of([skip(lit("a"))]), "a") == {:ok, []}
  end

  test "fail to parse because of the first parser" do
    assert parse(sequence_of([lit("a"), lit("b")]), "bb") == {:error,
      """
      Failed to match sequence_of#3([lit#1, lit#2]) at 1:1, because it failed to match lit#1("a") at 1:1
      """
    }
  end

  test "fail to parse because of the last parser" do
    assert parse(sequence_of([lit("a"), lit("b")]), "aa") == {:error,
      """
      Failed to match sequence_of#3([lit#1, lit#2]) at 1:1, because it failed to match lit#2("b") at 1:2
      """
    }
  end

  test "fail to parse for end of input" do
    assert parse(sequence_of([lit("aaa"), lit("bbb")]), "a") == {:error,
      """
      Failed to match sequence_of#3([lit#1, lit#2]) at 1:1, because it failed to match lit#1("aaa") at 1:1
      """
    }
  end

  test "notify events on success" do
    Helper.assert_events_notified(sequence_of([lit("a"), lit("b")]), "ab", [
      {:started, "sequence_of#3([lit#1, lit#2])"},
      {:matched, {0, 1, 1}, {1, 1, 2}, {2, 1, 3}},
    ])
  end

  test "notify events on failure because of first failed" do
    Helper.assert_events_notified(sequence_of([lit("a"), lit("b")]), "cc", [
      {:started, "sequence_of#3([lit#1, lit#2])"},
      {:failed, {0, 1, 1}},
    ])
  end

  test "notify events on failure because of last failed" do
    Helper.assert_events_notified(sequence_of([lit("a"), lit("b")]), "ac", [
      {:started, "sequence_of#3([lit#1, lit#2])"},
      {:failed, {0, 1, 1}},
    ])
  end
end
