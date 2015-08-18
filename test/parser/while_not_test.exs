defmodule Paco.Parser.WhileNotTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser
  import Paco.ASCII, only: [uppercase?: 1]

  test "parse characters not in alphabet as string" do
    assert parse(while_not("abc"), "dda") == {:ok, "dd"}
    assert parse(while_not("abc"), "abc") == {:ok, ""}
    assert parse(while_not("abc"), "") == {:ok, ""}
  end

  test "parse characters not in alphabet as list" do
    assert parse(while_not(["a", "b", "c"]), "dda") == {:ok, "dd"}
    assert parse(while_not(["a", "b", "c"]), "abc") == {:ok, ""}
    assert parse(while_not(["a", "b", "c"]), "") == {:ok, ""}
  end

  test "parse characters for which a given function returns false" do
    assert parse(while_not(&uppercase?/1), "abC") == {:ok, "ab"}
    assert parse(while_not(&uppercase?/1), "ABC") == {:ok, ""}
    assert parse(while_not(&uppercase?/1), "") == {:ok, ""}
  end

  test "parse characters not in alpahbet for an exact number of times" do
    assert parse(while_not("abc", 2), "ddd") == {:ok, "dd"}
    assert parse(while_not("abc", exactly: 2), "ddd") == {:ok, "dd"}

    assert parse(while_not("abc", 3), "ddb") == {:error,
      ~s|expected exactly 3 characters not in alphabet "abc" at 1:1 but got "ddb"|
    }
  end

  test "parse characters for which a given function returns false for an exact number of times" do
    assert parse(while_not(&uppercase?/1, 2), "abc") == {:ok, "ab"}
    assert parse(while_not(&uppercase?/1, exactly: 2), "abc") == {:ok, "ab"}

    assert parse(while_not(&uppercase?/1, 3), "abC") == {:error,
      ~s|expected exactly 3 characters which doesn't satisfy uppercase? at 1:1 but got "abC"|
    }
  end

  test "parse characters in alpahbet for a number of times" do
    assert parse(while_not("abc", at_most: 2), "ddefg") == {:ok, "dd"}
    assert parse(while_not("abc", less_than: 2), "ddefg") == {:ok, "d"}

    assert parse(while_not("abc", at_least: 3), "dda") == {:error,
      ~s|expected at least 3 characters not in alphabet "abc" at 1:1 but got "dda"|
    }
    assert parse(while_not("abc", more_than: 2), "dda") == {:error,
      ~s|expected at least 3 characters not in alphabet "abc" at 1:1 but got "dda"|
    }
  end
end
