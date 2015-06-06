defmodule Paco.Parser.WhitespaceTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse a single whitespace" do
    assert parse(whitespace, "  ") == {:ok, " "}
  end

  test "pase whitespaces" do
    assert parse(whitespaces, "   ") == {:ok, "   "}
  end

  test "fail to parse a single whitespace" do
    assert parse(whitespace, "a") == {:error,
      """
      Failed to match whitespace at 1:1
      """
    }
  end

  test "fail to parse whitespaces" do
    assert parse(whitespaces, "a") == {:error,
      """
      Failed to match whitespaces at 1:1
      """
    }
  end
end
