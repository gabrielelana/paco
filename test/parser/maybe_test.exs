defmodule Paco.Parser.MaybeTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "successes are kept" do
    assert parse("a", maybe(lit("a"))) == {:ok, "a"}
  end

  test "failures returns skipped empty results" do
    assert %Paco.Success{skip: true} = parse("b", maybe(lit("a")), format: :raw)
  end

  test "returns default value on failures" do
    assert parse("a", maybe(lit("a"), default: "a")) == {:ok, "a"}
    assert parse("b", maybe(lit("a"), default: "a")) == {:ok, "a"}
  end

  test "boxing" do
    assert parse("a", maybe("a")) == {:ok, "a"}
  end

  test "failures are skipped" do
    assert parse("b", sequence_of([maybe(lit("a")), lit("b")])) == {:ok, ["b"]}
  end

  test "fatal failures are skipped" do
    assert parse("b", sequence_of([cut, maybe(lit("a")), lit("b")])) == {:ok, ["b"]}
  end
end
