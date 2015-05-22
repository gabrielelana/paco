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
    assert describe(any) == "any#1(1)"
    assert describe(any(1)) == "any#2(1)"
    assert describe(any(4)) == "any#3(4)"
  end

  test "failure" do
    assert parse(any(3), "aa") == {:error,
      """
      Failed to match any#1(3) at 1:1, because it reached the end of input
      """
    }
  end

  test "notify events on success" do
    Helper.assert_events_notified(any(3), "aaa ", [
      {:started, "any#1(3)"},
      {:matched, {0, 1, 1}, {2, 1, 3}, {3, 1, 4}},
    ])
  end

  test "notify events on failure" do
    Helper.assert_events_notified(any(4), "aaa", [
      {:started, "any#1(4)"},
      {:failed, {0, 1, 1}}
    ])
  end

  test "stream success" do
    result = Helper.stream_of("aaab")
             |> Paco.Stream.parse(any(3))
             |> Enum.to_list

    assert result == ["aaa"]
  end

  test "stream failure" do
    result = Helper.stream_of("aa")
             |> Paco.Stream.parse(any(3))
             |> Enum.to_list

    assert result == []
  end
end
