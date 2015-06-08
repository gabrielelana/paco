defmodule Paco.Parser.AnyTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "parse any character for an exact number of times" do
    assert parse(any, "abc") == {:ok, "a"}
    assert parse(any(1), "abc") == {:ok, "a"}
    assert parse(any(exactly: 1), "abc") == {:ok, "a"}

    assert parse(any(2), "abc") == {:ok, "ab"}
    assert parse(any(3), "abc") == {:ok, "abc"}
  end

  test "works for composite graphemes" do
    assert parse(any, "e\x{0301}aaa") == {:ok, "e\x{0301}"}
  end

  test "parse any character for a number of times" do
    assert parse(any(at_most: 2), "abc") == {:ok, "ab"}
    assert parse(any(less_than: 2), "abc") == {:ok, "a"}

    assert parse(any(at_least: 3), "ab") == {:error,
      ~s|expected at least 3 characters at 1:1 but got "ab"|
    }
    assert parse(any(more_than: 2), "ab") == {:error,
      ~s|expected at least 3 characters at 1:1 but got "ab"|
    }
  end

  test "failure with description" do
    parser = any(at_least: 3) |> as("TOKEN")
    assert parse(parser, "ab") == {:error,
      ~s|expected at least 3 characters (TOKEN) at 1:1 but got "ab"|
    }
  end

  test "failure has rank" do
    parser = any(3)

    f1 = parser.parse.(Paco.State.from(""), parser)
    f2 = parser.parse.(Paco.State.from("a"), parser)
    f3 = parser.parse.(Paco.State.from("aa"), parser)

    assert f1.rank < f2.rank
    assert f2.rank < f3.rank
  end

  test "stream mode success" do
    for stream <- Helper.streams_of("abc") do
      result = stream
               |> Paco.Stream.parse(any(2))
               |> Enum.to_list

      assert result == ["ab"]
    end
  end

  test "stream mode success at the end of input" do
    for stream <- Helper.streams_of("ab") do
      result = stream
               |> Paco.Stream.parse(any(2))
               |> Enum.to_list

      assert result == ["ab"]
    end
  end

  test "stream mode failure because of the end of input" do
    for stream <- Helper.streams_of("ab") do
      result = stream
               |> Paco.Stream.parse(any(3))
               |> Enum.to_list

      assert result == []
    end
  end

  test "stream mode for an empty input" do
    result = [""]
             |> Paco.Stream.parse(any)
             |> Enum.to_list

    assert result == []
  end
end
