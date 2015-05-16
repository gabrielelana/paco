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
      Failed to match lex#1("aaa") at 1:1
      """
    }
  end

  test "notify events on success" do
    assert Helper.events_notified_by(lex("a"), " a ") == [
      {:loaded, " a "},
      {:started, "lex#1(\"a\")"},
      {:started, "surrounded_by#4(lit#2, regex#3, regex#3)"},
      {:started, "sequence_of#7([skip#5, lit#2, skip#6])"},
      {:started, "skip#5(regex#3)"},
      {:started, "regex#3(~r/\\s*/, [])"},
      {:matched, {0, 1, 1}, {0, 1, 1}, {1, 1, 2}},
      {:matched, {0, 1, 1}, {0, 1, 1}, {1, 1, 2}},
      {:started, "lit#2(\"a\")"},
      {:matched, {1, 1, 2}, {1, 1, 2}, {2, 1, 3}},
      {:started, "skip#6(regex#3)"},
      {:started, "regex#3(~r/\\s*/, [])"},
      {:matched, {2, 1, 3}, {2, 1, 3}, {3, 1, 4}},
      {:matched, {2, 1, 3}, {2, 1, 3}, {3, 1, 4}},
      {:matched, {0, 1, 1}, {2, 1, 3}, {3, 1, 4}},
      {:matched, {0, 1, 1}, {2, 1, 3}, {3, 1, 4}},
      {:matched, {0, 1, 1}, {2, 1, 3}, {3, 1, 4}}]
  end
end
