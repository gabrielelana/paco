defmodule Paco.Parser.LexemeTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

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

  test "notify events on success" do
    Helper.assert_events_notified(lex("a"), " a ", [
      {:started, ~s|lex("a")|},
      {:matched, {0, 1, 1}, {2, 1, 3}, {3, 1, 4}},
    ])
  end

  test "notify events on failure" do
    Helper.assert_events_notified(lex("a"), " b ", [
      {:started, ~s|lex("a")|},
      {:failed, {0, 1, 1}},
    ])
  end

  test "silences its internals" do
    parser = lex("a")

    assert explain(parser, " a ") == {:ok,
      """
      Matched lex("a") from 1:1 to 1:3
      1:  a
         ^ ^
      """
    }
    assert explain(parser, " b") == {:ok,
      """
      Failed to match lex("a") at 1:1
      1:  b
         ^
      """
    }
  end
end
