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

    assert result == ["aaa"]
  end

  test "wait for more text in stream mode until the end of input" do
    result = Helper.stream_of("aaa")
             |> Paco.Stream.parse(until("b"))
             |> Enum.to_list

    assert result == ["aaa"]
  end

  defp uppercase?(s) do
    s == String.upcase(s)
  end
end
