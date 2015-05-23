defmodule Paco.Parser.WhileTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "parse graphemes in alphabet" do
    assert parse(while("abc"), "bbacbcd") == {:ok, "bbacbc"}
  end

  test "parse graphemes for which a given function returns true" do
    assert parse(while(&uppercase?/1), "ABc") == {:ok, "AB"}
  end

  test "parse graphemes in alpahbet for an exact number of times" do
    assert parse(while("abc", 2), "bbacbcd") == {:ok, "bb"}
  end

  test "parse graphemes in alpahbet for a number of time less than (or equal to) m" do
    assert parse(while("abc", {:at_most, 2}), "bbacbc") == {:ok, "bb"}
    assert parse(while("abc", {:less_than, 2}), "bbacbc") == {:ok, "b"}
  end

  test "empty result is not a failure" do
    assert parse(while("abc"), "xxx") == {:ok, ""}
  end

  test "fails at the end of input when lower limit is not reached" do
    assert parse(while("abc", {:at_least, 3}), "ab") == {:error,
      """
      Failed to match while#1("abc", {3, :infinity}) at 1:1
      """
    }
  end

  test "fails when collected grahemes are less than required" do
    assert parse(while("abc", {:more_than, 2}), "abx") == {:error,
      """
      Failed to match while#1("abc", {3, :infinity}) at 1:1
      """
    }
  end

  test "notify events on success" do
    Helper.assert_events_notified(while("a"), "aaa ", [
      {:started, ~s|while#1("a", {0, :infinity})|},
      {:matched, {0, 1, 1}, {2, 1, 3}, {3, 1, 4}},
    ])
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

  defp uppercase?(s) do
    s == String.upcase(s)
  end
end
