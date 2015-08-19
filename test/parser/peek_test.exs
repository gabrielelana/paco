defmodule Paco.Parser.PeekTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse and returns the result but doesn't consume any input" do
    parser = peek(lit("a"))

    assert parse("a", parser) == {:ok, "a"}

    success = parser.parse.(Paco.State.from("a"), parser)
    assert success.result == "a"
    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
    assert success.at == {0, 1, 1}
    assert success.tail == "a"
  end

  test "it has no effect on failures" do
    assert parse("b", lit("a") |> peek) == parse("b", lit("a"))
  end
end
