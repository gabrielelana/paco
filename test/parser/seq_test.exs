defmodule Paco.Parser.SeqTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "parse sequence of parsers" do
    assert parse(sequence_of([string("a"), string("b")]), "ab") == {:ok, ["a", "b"]}
    assert parse(sequence_of([string("a")]), "a") == {:ok, ["a"]}
  end

  test "with no parsers" do
    assert_raise ArgumentError, fn -> sequence_of([]) end
  end

  test "describe" do
    assert describe(sequence_of([string("a"), string("b")])) == "sequence_of([string(a), string(b)])"
  end

  test "skipped parsers should be removed from result" do
    assert parse(sequence_of([string("a"), skip(string("b")), string("c")]), "abc") == {:ok, ["a", "c"]}
    assert parse(sequence_of([skip(string("a"))]), "a") == {:ok, []}
  end

  test "fail to parse because of the first parser" do
    assert parse(sequence_of([string("a"), string("b")]), "bb") == {:error,
      """
      Failed to match sequence_of([string(a), string(b)]) at 1:1, because it failed to match string(a) at 1:1
      """
    }
  end

  test "fail to parse because of the last parser" do
    assert parse(sequence_of([string("a"), string("b")]), "aa") == {:error,
      """
      Failed to match sequence_of([string(a), string(b)]) at 1:1, because it failed to match string(b) at 1:2
      """
    }
  end

  test "fail to parse for end of input" do
    assert parse(sequence_of([string("aaa"), string("bbb")]), "a") == {:error,
      """
      Failed to match sequence_of([string(aaa), string(bbb)]) at 1:1, because it failed to match string(aaa) at 1:1
      """
    }
  end

  test "notify events on success" do
    assert Helper.events_notified_by(sequence_of([string("a"), string("b")]), "ab") == [
      {:loaded, "ab"},
      {:started, "sequence_of([string(a), string(b)])"},
      {:started, "string(a)"},
      {:matched, {0, 1, 1}, {0, 1, 1}, {1, 1, 2}},
      {:started, "string(b)"},
      {:matched, {1, 1, 2}, {1, 1, 2}, {2, 1, 3}},
      {:matched, {0, 1, 1}, {1, 1, 2}, {2, 1, 3}},
    ]
  end

  test "notify events on failure" do
    assert Helper.events_notified_by(sequence_of([string("a"), string("b")]), "cc") == [
      {:loaded, "cc"},
      {:started, "sequence_of([string(a), string(b)])"},
      {:started, "string(a)"},
      {:failed, {0, 1, 1}},
      {:failed, {0, 1, 1}},
    ]
    assert Helper.events_notified_by(sequence_of([string("a"), string("b")]), "ac") == [
      {:loaded, "ac"},
      {:started, "sequence_of([string(a), string(b)])"},
      {:started, "string(a)"},
      {:matched, {0, 1, 1}, {0, 1, 1}, {1, 1, 2}},
      {:started, "string(b)"},
      {:failed, {1, 1, 2}},
      {:failed, {0, 1, 1}},
    ]
  end
end
