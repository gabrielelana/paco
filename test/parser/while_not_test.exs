defmodule Paco.Parser.WhileNotTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser
  import Paco.ASCII, only: [uppercase?: 1]

  test "parse characters not in alphabet as string" do
    assert parse("dda", while_not("abc")) == {:ok, "dd"}
    assert parse("abc", while_not("abc")) == {:ok, ""}
    assert parse("", while_not("abc")) == {:ok, ""}
  end

  test "parse characters not in alphabet as list" do
    assert parse("dda", while_not(["a", "b", "c"])) == {:ok, "dd"}
    assert parse("abc", while_not(["a", "b", "c"])) == {:ok, ""}
    assert parse("", while_not(["a", "b", "c"])) == {:ok, ""}
  end

  test "parse characters for which a given function returns false" do
    assert parse("abC", while_not(&uppercase?/1)) == {:ok, "ab"}
    assert parse("ABC", while_not(&uppercase?/1)) == {:ok, ""}
    assert parse("", while_not(&uppercase?/1)) == {:ok, ""}
  end

  test "parse characters not in alpahbet for an exact number of times" do
    assert parse("ddd", while_not("abc", 2)) == {:ok, "dd"}
    assert parse("ddd", while_not("abc", exactly: 2)) == {:ok, "dd"}

    assert parse("ddb", while_not("abc", 3)) == {:error,
      ~s|expected exactly 3 characters not in alphabet "abc" at 1:1 but got "ddb"|
    }
  end

  test "parse characters for which a given function returns false for an exact number of times" do
    assert parse("abc", while_not(&uppercase?/1, 2)) == {:ok, "ab"}
    assert parse("abc", while_not(&uppercase?/1, exactly: 2)) == {:ok, "ab"}

    assert parse("abC", while_not(&uppercase?/1, 3)) == {:error,
      ~s|expected exactly 3 characters which doesn't satisfy uppercase? at 1:1 but got "abC"|
    }
  end

  test "parse characters in alpahbet for a number of times" do
    assert parse("ddefg", while_not("abc", at_most: 2)) == {:ok, "dd"}
    assert parse("ddefg", while_not("abc", less_than: 2)) == {:ok, "d"}

    assert parse("dda", while_not("abc", at_least: 3)) == {:error,
      ~s|expected at least 3 characters not in alphabet "abc" at 1:1 but got "dda"|
    }
    assert parse("dda", while_not("abc", more_than: 2)) == {:error,
      ~s|expected at least 3 characters not in alphabet "abc" at 1:1 but got "dda"|
    }
  end
end
