defmodule Paco.Parser.WhileTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "success" do
    assert parse(while("abc"), "bbacbcd") == {:ok, "bbacbc"}
    assert parse(while(&uppercase?/1), "ABc") == {:ok, "AB"}
  end

  test "empty result is not a failure" do
    assert parse(while("abc"), "xxx") == {:ok, ""}
  end

  test "notify events on success" do
    Helper.assert_events_notified(while("a"), "aaa ", [
      {:started, ~s|while#1("a")|},
      {:matched, {0, 1, 1}, {2, 1, 3}, {3, 1, 4}},
    ])
  end

  test "stream mode while matching" do
    result = Helper.stream_of("aaab")
             |> Paco.Stream.parse(while("a"))
             |> Enum.to_list

    assert result == ["aaa"]
  end

  test "stream mode while not matching" do
    result = Helper.stream_of("aaab")
             |> Paco.Stream.parse(while("b"))
             |> Enum.to_list

    assert result == []
  end

  test "stream mode while matching till the end of input" do
    result = Helper.stream_of("aaa")
             |> Paco.Stream.parse(while("a"))
             |> Enum.to_list

    assert result == ["aaa"]
  end

  test "stream mode for an empty input" do
    result = [""]
             |> Paco.Stream.parse(while("a"))
             |> Enum.to_list

    assert result == []
  end

  defp uppercase?(s) do
    s == String.upcase(s)
  end
end
