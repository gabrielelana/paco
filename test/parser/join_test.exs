defmodule Paco.Parser.JoinTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "success" do
    parser = sequence_of([lit("a"), lit("b")])

    assert parse(parser, "ab") == {:ok, ["a", "b"]}
    assert parse(parser |> join, "ab") == {:ok, "ab"}
    assert parse(parser |> join("-"), "ab") == {:ok, "a-b"}
  end

  test "doesn't join failures" do
    parser = sequence_of([lit("a"), lit("b")]) |> join

    assert parse(parser, "ac") == {:error, ~s|expected "b" at 1:2 but got "c"|}
  end

  test "fails when results are not convertible to binaries" do
    parser = [{"a"}, {"b"}] |> join

    assert parse(parser, "ab") == {:error,
      ~s|exception: protocol String.Chars not implemented for {"a"} at 1:1|
    }
  end
end
