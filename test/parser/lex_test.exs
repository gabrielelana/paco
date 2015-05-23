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
    assert describe(lex("a")) == ~s|lex#1("a")|
  end

  test "failure" do
    assert parse(lex("aaa"), "bbb") == {:error,
      """
      Failed to match lex#1("aaa") at 1:1, because it failed to match lit#2("aaa") at 1:1
      """
    }
  end

  test "notify events on success" do
    Helper.assert_events_notified(lex("a"), " a ", [
      {:started, ~s|lex#1("a")|},
      {:matched, {0, 1, 1}, {2, 1, 3}, {3, 1, 4}},
    ])
  end

  test "notify events on failure" do
    Helper.assert_events_notified(lex("a"), " b ", [
      {:started, ~s|lex#1("a")|},
      {:failed, {0, 1, 1}},
    ])
  end
end
