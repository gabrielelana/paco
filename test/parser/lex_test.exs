defmodule Paco.Parser.LexemeTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "success" do
    assert parse(lex("a"), "a") == {:ok, "a"}
    assert parse(lex("a"), " a") == {:ok, "a"}
    assert parse(lex("a"), "\na") == {:ok, "a"}
    assert parse(lex("a"), "  a") == {:ok, "a"}
    assert parse(lex("a"), "a ") == {:ok, "a"}
    assert parse(lex("a"), "a\n") == {:ok, "a"}
    assert parse(lex("a"), "a  ") == {:ok, "a"}
    assert parse(lex("aaa"), "aaa") == {:ok, "aaa"}
  end

  test "describe" do
    assert describe(lex("a")) == ~s|lex("a")|
  end

  test "failure" do
    assert parse(lex("aaa"), "bbb") == {:error,
      """
      Failed to match lex("aaa") at 1:1, \
      because it failed to match lit("aaa") at 1:1
      """
    }
  end
end
