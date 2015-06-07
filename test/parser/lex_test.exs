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

  test "failure" do
    assert parse(lex("aaa"), "bbb") == {:error,
      ~s|expected "aaa" at 1:1 but got "bbb"|
    }
  end

  test "failure with description" do
    assert parse(lex("aaa") |> as("LEX"), "bbb") == {:error,
      ~s|expected "aaa" (LEX) at 1:1 but got "bbb"|
    }
  end
end
