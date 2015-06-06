defmodule Paco.Parser.WhileTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser
  import Paco.String, only: [uppercase?: 1]

  alias Paco.Test.Helper

  test "parse characters in alphabet" do
    assert parse(while("abc"), "bbacbcd") == {:ok, "bbacbc"}
    assert parse(while("abc"), "xxx") == {:ok, ""}
    assert parse(while("abc"), "") == {:ok, ""}
  end

  test "parse characters for which a given function returns true" do
    assert parse(while(&uppercase?/1), "ABc") == {:ok, "AB"}
    assert parse(while(&uppercase?/1), "abc") == {:ok, ""}
    assert parse(while(&uppercase?/1), "") == {:ok, ""}
  end

  test "parse characters in alpahbet for an exact number of times" do
    assert parse(while("abc", 2), "bbacbcd") == {:ok, "bb"}
    assert parse(while("abc", exactly: 2), "bbacbcd") == {:ok, "bb"}

    assert parse(while("abc", 3), "aad") == {:error,
      ~s|expected exactly 3 characters in alphabet "abc" at 1:1 but got "aad", unexpected "d" at 1:3|
    }
  end

  test "parse characters for which a given function returns true for an exact number of times" do
    assert parse(while(&uppercase?/1, 2), "ABC") == {:ok, "AB"}
    assert parse(while(&uppercase?/1, exactly: 2), "ABC") == {:ok, "AB"}

    assert parse(while(&uppercase?/1, 3), "ABc") == {:error,
      ~s|expected exactly 3 characters which satisfy uppercase? at 1:1 but got "ABc", unexpected "c" at 1:3|
    }
  end

  test "parse characters in alpahbet for a number of times" do
    assert parse(while("abc", at_most: 2), "bbacbc") == {:ok, "bb"}
    assert parse(while("abc", less_than: 2), "bbacbc") == {:ok, "b"}

    assert parse(while("abc", at_least: 3), "aad") == {:error,
      ~s|expected at least 3 characters in alphabet "abc" at 1:1 but got "aad", unexpected "d" at 1:3|
    }
    assert parse(while("abc", more_than: 2), "aad") == {:error,
      ~s|expected at least 3 characters in alphabet "abc" at 1:1 but got "aad", unexpected "d" at 1:3|
    }
  end

  test "stream mode" do
    for stream <- Helper.streams_of("aab") do
      result = stream
               |> Paco.Stream.parse(while("a"))
               |> Enum.to_list

      assert result == ["aa"]
    end
  end

  test "stream mode failure" do
    for stream <- Helper.streams_of("aab") do
      result = stream
               |> Paco.Stream.parse(while("b"))
               |> Enum.to_list

      assert result == []
    end
  end

  test "stream mode stop at the end of input" do
    for stream <- Helper.streams_of("aa") do
      result = stream
               |> Paco.Stream.parse(while("a"))
               |> Enum.to_list

      assert result == ["aa"]
    end
  end

  test "stream mode for an empty input" do
    result = [""]
             |> Paco.Stream.parse(while("a"))
             |> Enum.to_list

    assert result == []
  end

  test "stream mode waits until it has enough" do
    for stream <- Helper.streams_of("aaa") do
      result = stream
               |> Paco.Stream.parse(while("a", {0, 3}))
               |> Enum.to_list

      assert result == ["aaa"]
    end
  end
end
