defmodule Paco.Parser.SeparatedByTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "success" do
    parser = lit("a") |> separated_by(lex(","))

    assert parse(parser, "a") == {:ok, ["a"]}
    assert parse(parser, "a,a") == {:ok, ["a", "a"]}
    assert parse(parser, "a,a,a") == {:ok, ["a", "a", "a"]}
    assert parse(parser, "a, a, a") == {:ok, ["a", "a", "a"]}
  end

  test "fails when empty" do
    parser = lit("a") |> separated_by(lex(","))

    assert parse(parser, "") == {:error,
      """
      Failed to match separated_by(lit("a"), lex(",")) at 1:1, \
      because it failed to match lit("a") at 1:1, \
      because it reached the end of input
      """
    }
  end
end
