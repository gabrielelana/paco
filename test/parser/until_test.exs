defmodule Paco.Parser.UntilTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "success" do
    assert parse(until("c"), "abc") == {:ok, "ab"}
    assert parse(until({"c", "\\"}), "ab\\cdce") == {:ok, "ab\\cd"}
    assert parse(until(&uppercase?/1), "abC") == {:ok, "ab"}
  end

  test "any works for composite graphemes" do
    assert parse(any, "e\x{0301}aaa") == {:ok, "e\x{0301}"}
  end

  test "describe" do
    assert describe(until("c")) == ~s|until#1("c", [])|
    # assert describe(until(&uppercase?/1)) == "until#1(1)"
  end

  test "empty result is not a failure" do
    assert parse(until("c"), "ccc") == {:ok, ""}
  end

  test "notify events on success" do
    Helper.assert_events_notified(until(" "), "aaa ", [
      {:started, ~s|until#1(" ", [])|},
      {:matched, {0, 1, 1}, {2, 1, 3}, {3, 1, 4}},
    ])
  end

  test "wait for more text in stream mode" do
    result = Helper.stream_of("aaab")
             |> Paco.Stream.parse(until("b"))
             |> Enum.to_list

    # Helper.stream_of will emit one character at the time, the until
    # combinator would be happy to match the first "a" and return it as result,
    # but by default the until combinator is told to wait for more input. If
    # you want it to return with a result as soon as possibile, use the option
    # [wait_for_more: false] (see the next test)

    # upstream -> "a" -> until("b") -> more
    # upstream -> "aa" -> until("b") -> more
    # upstream -> "aaa" -> until("b") -> more
    # upstream -> "aabb" -> until("b") -> "aaa"
    # upstream -> "b" -> until("b") -> halt
    assert result == ["aaa"]
  end

  test "return as soon as possibile in stream mode" do
    result = Helper.stream_of("aaab")
             |> Paco.Stream.parse(until("b"), wait_for_more: false)
             |> Enum.to_list

    # upstream -> "a" -> until("b") -> "a"
    # upstream -> "a" -> until("b") -> "a"
    # upstream -> "a" -> until("b") -> "a"
    # upstream -> "b" -> until("b") -> halt
    assert result == ["a", "a", "a"]

    # You can pass the same option to the parser
    result = Helper.stream_of("aaab")
             |> Paco.Stream.parse(until("b", wait_for_more: false))
             |> Enum.to_list

    assert result == ["a", "a", "a"]
  end

  defp uppercase?(s) do
    s == String.upcase(s)
  end
end
