defmodule Paco.Parser.WhileTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser
  import Paco.ASCII, only: [uppercase?: 1]

  alias Paco.Test.Helper

  test "parse characters in alphabet as string" do
    assert parse("bbacbcd", while("abc")) == {:ok, "bbacbc"}
    assert parse("xxx", while("abc")) == {:ok, ""}
    assert parse("", while("abc")) == {:ok, ""}
  end

  test "parse characters in alphabet as list" do
    assert parse("bbacbcd", while(["a", "b", "c"])) == {:ok, "bbacbc"}
    assert parse("xxx", while(["a", "b", "c"])) == {:ok, ""}
    assert parse("", while(["a", "b", "c"])) == {:ok, ""}
  end

  test "parse characters for which a given function returns true" do
    assert parse("ABc", while(&uppercase?/1)) == {:ok, "AB"}
    assert parse("abc", while(&uppercase?/1)) == {:ok, ""}
    assert parse("", while(&uppercase?/1)) == {:ok, ""}
  end

  test "parse characters in alpahbet for an exact number of times" do
    assert parse("bbacbcd", while("abc", 2)) == {:ok, "bb"}
    assert parse("bbacbcd", while("abc", exactly: 2)) == {:ok, "bb"}

    assert parse("aad", while("abc", 3)) == {:error,
      ~s|expected exactly 3 characters in alphabet "abc" at 1:1 but got "aad"|
    }
  end

  test "parse characters for which a given function returns true for an exact number of times" do
    assert parse("ABC", while(&uppercase?/1, 2)) == {:ok, "AB"}
    assert parse("ABC", while(&uppercase?/1, exactly: 2)) == {:ok, "AB"}

    assert parse("ABc", while(&uppercase?/1, 3)) == {:error,
      ~s|expected exactly 3 characters which satisfy uppercase? at 1:1 but got "ABc"|
    }
  end

  test "parse characters in alpahbet for a number of times" do
    assert parse("bbacbc", while("abc", at_most: 2)) == {:ok, "bb"}
    assert parse("bbacbc", while("abc", less_than: 2)) == {:ok, "b"}

    assert parse("aad", while("abc", at_least: 3)) == {:error,
      ~s|expected at least 3 characters in alphabet "abc" at 1:1 but got "aad"|
    }
    assert parse("xxyy", while(["a", "b", "c"], at_least: 2)) == {:error,
      ~s|expected at least 2 characters in alphabet "abc" at 1:1 but got "xx"|
    }
    assert parse("aad", while("abc", more_than: 2)) == {:error,
      ~s|expected at least 3 characters in alphabet "abc" at 1:1 but got "aad"|
    }
  end

  test "failure with description" do
    parser = while(&uppercase?/1, 3) |> as("TOKEN")
    assert parse("ABc", parser) == {:error,
      ~s|expected exactly 3 characters which satisfy uppercase? (TOKEN) at 1:1 but got "ABc"|
    }
  end

  test "failure keeps the relevant part of the tail" do
    assert parse("xxyy", while("abc", at_least: 2)) == {:error,
      ~s|expected at least 2 characters in alphabet "abc" at 1:1 but got "xx"|
    }
    assert parse("xxxyyy", while("abc", more_than: 2)) == {:error,
      ~s|expected at least 3 characters in alphabet "abc" at 1:1 but got "xxx"|
    }
  end

  test "failure has rank" do
    parser = while(&uppercase?/1, 3)

    f1 = parser.parse.(Paco.State.from("aaa"), parser)
    f2 = parser.parse.(Paco.State.from("Aaa"), parser)
    f3 = parser.parse.(Paco.State.from("AAa"), parser)

    assert f1.rank < f2.rank
    assert f2.rank < f3.rank
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
