defmodule Paco.Parser.UntilTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "parse success" do
    assert parse(until(1), "abc") == {:ok, "a"}
    assert parse(until(3), "abc") == {:ok, "abc"}
    assert parse(until(&uppercase?/1), "ABc") == {:ok, "AB"}
    assert parse(until("c"), "abc") == {:ok, "ab"}
    assert parse(until({"c", "\\"}), "ab\\cdce") == {:ok, "ab\\cd"}
  end

  test "describe" do
    assert describe(until(1)) == "until#1(1)"
    # assert describe(until(&uppercase?/1)) == "until#1(1)"
  end

  test "empty result is not a failure" do
    assert parse(until("c"), "ccc") == {:ok, ""}
  end

  test "failure" do
    assert parse(until(4), "bbb") == {:error,
      """
      Failed to match until#1(4) at 1:1
      """
    }
  end

  test "notify events on success" do
    Helper.assert_events_notified(until(" "), "aaa ", [
      {:started, ~s|until#1(" ")|},
      {:matched, {0, 1, 1}, {2, 1, 3}, {3, 1, 4}},
    ])
  end

  test "notify events on failure" do
    Helper.assert_events_notified(until(4), "aaa", [
      {:started, "until#1(4)"},
      {:failed, {0, 1, 1}}
    ])
  end

  test "wait for more text in stream mode" do
    [result] = Helper.stream_of("aaab")
             |> Paco.Stream.parse(until(4))
             |> Enum.to_list

    assert result == "aaab"
  end

  defp uppercase?(s) do
    s == String.upcase(s)
  end
end