defmodule Paco.Parser.WhitespaceTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse a single whitespace" do
    assert parse(whitespace, "  ") == {:ok, " "}
  end

  test "parse whitespaces" do
    assert parse(whitespaces, "   ") == {:ok, "   "}
  end

  test "fail to parse a single whitespace" do
    assert parse(whitespace, "a") == {:error,
      ~s|expected 1 whitespace at 1:1 but got "a"|
    }
  end

  test "fail to parse whitespaces" do
    assert parse(whitespaces, "a") == {:error,
      ~s|expected at least 1 whitespace at 1:1 but got "a"|
    }
  end
end
