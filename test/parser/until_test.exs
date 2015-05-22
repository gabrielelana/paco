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

  test "stream mode until a boundary" do
    result = Helper.stream_of("aaab")
             |> Paco.Stream.parse(until("b"))
             |> Enum.to_list

    assert result == ["aaa"]
  end

  test "stream mode until a boundary with escape" do
    result = Helper.stream_of("aa\\baab")
             |> Paco.Stream.parse(until({"b", "\\"}))
             |> Enum.to_list

    assert result == ["aa\\baa"]
  end

  test "stream mode until end of input" do
    result = Helper.stream_of("aaa")
             |> Paco.Stream.parse(until("b"))
             |> Enum.to_list

    assert result == ["aaa"]
  end

  test "stream mode for an empty input" do
    result = [""]
             |> Paco.Stream.parse(until("b"))
             |> Enum.to_list

    assert result == []
  end

  defp uppercase?(s) do
    s == String.upcase(s)
  end
end
