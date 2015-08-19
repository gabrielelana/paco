defmodule Paco.Parser.LexemeTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "success" do
    assert parse("a", lex("a")) == {:ok, "a"}
    assert parse(" a", lex("a")) == {:ok, "a"}
    assert parse("  a", lex("a")) == {:ok, "a"}
    assert parse("a ", lex("a")) == {:ok, "a"}
    assert parse("a  ", lex("a")) == {:ok, "a"}
    assert parse("aaa", lex("aaa")) == {:ok, "aaa"}
  end

  test "does not consumes newlines" do
    assert parse("\n", lex("a")) == {:error,
      ~s|expected "a" at 1:1 but got "\n"|
    }
  end

  test "failure" do
    assert parse("bbb", lex("aaa")) == {:error,
      ~s|expected "aaa" at 1:1 but got "bbb"|
    }
  end

  test "failure with description" do
    assert parse("bbb", lex("aaa") |> as("LEX")) == {:error,
      ~s|expected "aaa" (LEX) at 1:1 but got "bbb"|
    }
  end
end
