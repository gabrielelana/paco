defmodule Paco.Parser.MaybeTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "parse never fails" do
    assert parse(maybe(literal("a")), "a") == {:ok, "a"}
    assert parse(maybe(literal("a")), "b") == {:ok, []}
  end

  test "on failure it's skipped" do
    assert parse(sequence_of([maybe(literal("a")), literal("b")]), "b") == {:ok, ["b"]}
  end

  test "describe" do
    assert describe(maybe(literal("a"))) == "maybe(literal(a))"
  end

  test "notify events on combined success" do
    assert Helper.events_notified_by(maybe(literal("aaa")), "aaa") == [
      {:loaded, "aaa"},
      {:started, "maybe(literal(aaa))"},
      {:started, "literal(aaa)"},
      {:matched, {0, 1, 1}, {2, 1, 3}, {3, 1, 4}},
      {:matched, {0, 1, 1}, {2, 1, 3}, {3, 1, 4}},
    ]
  end

  test "notify events on combined failure" do
    assert Helper.events_notified_by(maybe(literal("aaa")), "bbb") == [
      {:loaded, "bbb"},
      {:started, "maybe(literal(aaa))"},
      {:started, "literal(aaa)"},
      {:failed, {0, 1, 1}},
      {:matched, {0, 1, 1}, {0, 1, 1}, {0, 1, 1}},
    ]
  end
end
