defmodule Paco.Parser.MaybeTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "parse never fails" do
    assert parse(maybe(lit("a")), "a") == {:ok, "a"}
    assert parse(maybe(lit("a")), "b") == {:ok, []}
  end

  test "parse with default" do
    assert parse(maybe(lit("a"), default: "a"), "a") == {:ok, "a"}
    assert parse(maybe(lit("a"), default: "a"), "b") == {:ok, "a"}
  end

  test "on failure it's skipped" do
    assert parse(sequence_of([maybe(lit("a")), lit("b")]), "b") == {:ok, ["b"]}
  end

  test "describe" do
    assert describe(maybe(lit("a"))) == ~s|maybe(lit("a"))|
    assert describe(maybe(lit("a"), default: "a")) == ~s|maybe(lit("a"), [default: "a"])|
  end

  test "notify events on combined success" do
    Helper.assert_events_notified(maybe(lit("aaa")), "aaa", [
      {:started, ~s|maybe(lit("aaa"))|},
      {:matched, {0, 1, 1}, {2, 1, 3}, {3, 1, 4}},
    ])
  end

  test "notify events on combined failure" do
    Helper.assert_events_notified(maybe(lit("aaa")), "bbb", [
      {:started, ~s|maybe(lit("aaa"))|},
      {:matched, {0, 1, 1}, {0, 1, 1}, {0, 1, 1}},
    ])
  end
end
