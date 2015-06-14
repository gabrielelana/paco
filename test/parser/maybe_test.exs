defmodule Paco.Parser.MaybeTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "successes are kept" do
    assert parse(maybe(lit("a")), "a") == {:ok, "a"}
  end

  test "failures returns skipped empty results" do
    assert %Paco.Success{skip: true} = parse(maybe(lit("a")), "b", format: :raw)
  end

  test "returns default value on failures" do
    assert parse(maybe(lit("a"), default: "a"), "a") == {:ok, "a"}
    assert parse(maybe(lit("a"), default: "a"), "b") == {:ok, "a"}
  end

  test "boxing" do
    assert parse(maybe("a"), "a") == {:ok, "a"}
  end

  test "failures are skipped" do
    assert parse(sequence_of([maybe(lit("a")), lit("b")]), "b") == {:ok, ["b"]}
  end

  test "fatal failures are skipped" do
    assert parse(sequence_of([cut, maybe(lit("a")), lit("b")]), "b") == {:ok, ["b"]}
  end
end
