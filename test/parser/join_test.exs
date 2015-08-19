defmodule Paco.Parser.JoinTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "success" do
    parser = sequence_of([lit("a"), lit("b")])

    assert parse("ab", parser) == {:ok, ["a", "b"]}
    assert parse("ab", parser |> join) == {:ok, "ab"}
    assert parse("ab", parser |> join("-")) == {:ok, "a-b"}
  end

  test "doesn't join failures" do
    parser = sequence_of([lit("a"), lit("b")]) |> join

    assert parse("ac", parser) == {:error, ~s|expected "b" at 1:2 but got "c"|}
  end

  test "fails when results are not convertible to binaries" do
    parser = [{"a"}, {"b"}] |> join

    assert parse("ab", parser) == {:error,
      ~s|exception: protocol String.Chars not implemented for {"a"} at 1:1|
    }
  end
end
