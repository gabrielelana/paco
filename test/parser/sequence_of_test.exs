defmodule Paco.Parser.SequenceOfTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "parse sequence of parsers" do
    assert parse(sequence_of([lit("a"), lit("b")]), "ab") == {:ok, ["a", "b"]}
    assert parse(sequence_of([lit("a")]), "a") == {:ok, ["a"]}
    assert parse(sequence_of([]), "a") == {:ok, []}
  end

  test "describe" do
    assert describe(sequence_of([lit("a"), lit("b")])) ==
      ~s|sequence_of([lit("a"), lit("b")])|
  end

  test "skipped parsers should be removed from result" do
    assert parse(sequence_of([lit("a"), skip(lit("b")), lit("c")]), "abc") == {:ok, ["a", "c"]}
    assert parse(sequence_of([skip(lit("a"))]), "a") == {:ok, []}
  end

  test "fail to parse because of the first parser" do
    assert parse(sequence_of([lit("a"), lit("b")]), "bb") == {:error,
      """
      Failed to match sequence_of([lit("a"), lit("b")]) at 1:1, \
      because it failed to match lit("a") at 1:1
      """
    }
  end

  test "fail to parse because of the last parser" do
    assert parse(sequence_of([lit("a"), lit("b")]), "aa") == {:error,
      """
      Failed to match sequence_of([lit("a"), lit("b")]) at 1:1, \
      because it failed to match lit("b") at 1:2
      """
    }
  end

  test "fail to parse for end of input" do
    assert parse(sequence_of([lit("aaa"), lit("bbb")]), "a") == {:error,
      """
      Failed to match sequence_of([lit("aaa"), lit("bbb")]) at 1:1, \
      because it failed to match lit("aaa") at 1:1, \
      because it reached the end of input
      """
    }
  end

  test "notify events on success" do
    Helper.assert_events_notified(sequence_of([lit("a"), lit("b")]), "ab", [
      {:started, ~s|sequence_of([lit("a"), lit("b")])|},
      {:matched, {0, 1, 1}, {1, 1, 2}, {2, 1, 3}},
    ])
  end

  test "notify events on failure because of first failed" do
    Helper.assert_events_notified(sequence_of([lit("a"), lit("b")]), "cc", [
      {:started, ~s|sequence_of([lit("a"), lit("b")])|},
      {:failed, {0, 1, 1}},
    ])
  end

  test "notify events on failure because of last failed" do
    Helper.assert_events_notified(sequence_of([lit("a"), lit("b")]), "ac", [
      {:started, ~s|sequence_of([lit("a"), lit("b")])|},
      {:failed, {0, 1, 1}},
    ])
  end

  test "do not consume input with a partial failure" do
    parser = sequence_of([lit("a"), lit("b")])
    failure = parser.parse.(Paco.State.from("aa"), parser)
    assert failure.at == {0, 1, 1}
    assert failure.tail == "aa"
  end

  test "fails in stream mode when don't consume any input" do
    result = [""]
             |> Paco.Stream.parse(sequence_of([]))
             |> Enum.to_list
    assert result == []

    result = [""]
             |> Paco.Stream.parse(sequence_of([]), on_failure: :yield)
             |> Enum.to_list
    assert result == [{:error,
      """
      Failed to match sequence_of() at 1:1, \
      because it didn't consume any input
      """
    }]
  end
end
