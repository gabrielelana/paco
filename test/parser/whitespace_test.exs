defmodule Paco.Parser.WhitespaceTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse a single whitespace" do
    assert parse(whitespace, "  ") == {:ok, " "}
  end

  test "fail to parse a single whitespace" do
    assert parse(whitespace, "a") == {:error,
      """
      Failed to match whitespace#1 at 1:1
      """
    }
  end

  test "silences its internals" do
    parser = whitespace

    assert explain(parser, " ") == {:ok,
      """
      Matched whitespace#1 from 1:1 to 1:1
      1:
         ^
      """
    }
    assert explain(parser, "a") == {:ok,
      """
      Failed to match whitespace#1 at 1:1
      1: a
         ^
      """
    }
  end

  test "paser whitespaces" do
    assert parse(whitespaces, "   ") == {:ok, "   "}
  end

  test "fail to parse whitespaces" do
    assert parse(whitespaces, "a") == {:error,
      """
      Failed to match whitespaces#1 at 1:1
      """
    }
  end

  test "whitespaces silences its internals" do
    parser = whitespaces

    assert explain(parser, "   ") == {:ok,
      """
      Matched whitespaces#1 from 1:1 to 1:3
      1:
         ^ ^
      """
    }
    assert explain(parser, "a") == {:ok,
      """
      Failed to match whitespaces#1 at 1:1
      1: a
         ^
      """
    }
  end
end
