defmodule Paco.Parser.AnyTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "success" do
    assert parse(any, "abc") == {:ok, "a"}
    assert parse(any(1), "abc") == {:ok, "a"}
    assert parse(any(2), "abc") == {:ok, "ab"}
    assert parse(any(1), "abc") == {:ok, "a"}
  end

  test "works for composite graphemes" do
    assert parse(any, "e\x{0301}aaa") == {:ok, "e\x{0301}"}
  end

  test "describe" do
    assert describe(any) == "any(1)"
    assert describe(any(1)) == "any(1)"
    assert describe(any(4)) == "any(4)"
  end

  test "failure" do
    assert parse(any(3), "aa") == {:error,
      """
      Failed to match any(3) at 1:1, because it reached the end of input
      """
    }
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
