defmodule Paco.Parser.KeepTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "keep what is skipped" do
    assert parse(surrounded_by(lit("a"), lex("*")), "*a*") == {:ok, "a"}

    assert parse(surrounded_by(lit("a"), keep(lex("*"))), "*a*") == {:ok, ["*", "a", "*"]}
  end

  test "failures are ignored" do
    parser = surrounded_by(lit("a"), keep(lex("*")))

    assert parse(parser, "[a]") == {:error,
      """
      Failed to match surrounded_by(lit("a"), keep(lex("*")), keep(lex("*"))) at 1:1, \
      because it failed to match lex("*") at 1:1, \
      because it failed to match lit("*") at 1:1
      """
    }
  end

  test "keep a skip" do
    parser = keep(skip(lit("a")))
    success = parser.parse.(Paco.State.from("a"), parser)
    assert success.keep == false
    assert success.skip == false
  end

  test "skip a keep" do
    parser = skip(keep(lit("a")))
    success = parser.parse.(Paco.State.from("a"), parser)
    assert success.keep == false
    assert success.skip == false
  end
end
