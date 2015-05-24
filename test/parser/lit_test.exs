defmodule Paco.Parser.LiteralTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "success" do
    assert parse(lit("aaa"), "aaa") == {:ok, "aaa"}
    assert parse(lit("あいうえお"), "あいうえお") == {:ok, "あいうえお"}
    assert parse(lit(""), "") == {:ok, ""}
  end

  test "describe" do
    assert describe(lit("a")) == ~s|lit("a")|
    assert describe(lit("\n")) == ~s|lit("\\n")|
  end

  test "failure" do
    assert parse(lit("aaa"), "bbb") == {:error,
      """
      Failed to match lit("aaa") at 1:1
      """
    }
  end

  test "skipped parsers should be removed from result" do
    assert parse(skip(lit("a")), "a") == {:ok, []}
  end

  test "skip doesn't influece failures" do
    assert parse(skip(lit("aaa")), "bbb") == {:error,
      """
      Failed to match lit("aaa") at 1:1
      """
    }
  end

  test "failure for end of input" do
    assert parse(lit("aaa"), "aa") == {:error,
      """
      Failed to match lit("aaa") at 1:1
      """
    }
  end

  test "notify events on success" do
    Helper.assert_events_notified(lit("aaa"), "aaa", [
      {:started, ~s|lit("aaa")|},
      {:matched, {0, 1, 1}, {2, 1, 3}, {3, 1, 4}},
    ])
  end

  test "notify events on failure" do
    Helper.assert_events_notified(lit("bbb"), "aaa", [
      {:started, ~s|lit("bbb")|},
      {:failed, {0, 1, 1}},
    ])
  end

  test "increment indexes for a match" do
    parser = lit("aaa")
    success = parser.parse.(Paco.State.from("aaa"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {2, 1, 3}
    assert success.at == {3, 1, 4}
    assert success.tail == ""
  end

  test "increment indexes for a match with newlines" do
    parser = lit("a\na\na\n")
    success = parser.parse.(Paco.State.from("a\na\na\nbbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {5, 3, 2}
    assert success.at == {6, 4, 1}
    assert success.tail == "bbb"
  end

  test "increment indexes for a single character match" do
    parser = lit("a")
    success = parser.parse.(Paco.State.from("aaa"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
    assert success.at == {1, 1, 2}
    assert success.tail == "aa"
  end

  test "indexes for an empty match" do
    parser = lit("")
    success = parser.parse.(Paco.State.from("aaa"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
    assert success.at == {0, 1, 1}
    assert success.tail == "aaa"
  end

  test "indexes for a failure" do
    parser = lit("a")
    failure = parser.parse.(Paco.State.from("bbb"), parser)
    assert failure.at == {0, 1, 1}
    assert failure.tail == "bbb"
  end

  test "stream mode success" do
    for stream <- Helper.streams_of("abc") do
      result = stream
               |> Paco.Stream.parse(lit("ab"))
               |> Enum.to_list

      assert result == ["ab"]
    end
  end

  test "stream mode success at the end of input" do
    for stream <- Helper.streams_of("ab") do
      result = stream
               |> Paco.Stream.parse(lit("ab"))
               |> Enum.to_list

      assert result == ["ab"]
    end
  end

  test "stream mode failure" do
    for stream <- Helper.streams_of("bb") do
      result = stream
               |> Paco.Stream.parse(lit("ab"))
               |> Enum.to_list

      assert result == []
    end
  end

  test "stream mode failure because of the end of input" do
    for stream <- Helper.streams_of("aa") do
      result = stream
               |> Paco.Stream.parse(lit("aaa"))
               |> Enum.to_list

      assert result == []
    end
  end

  test "stream mode for an empty input" do
    result = [""]
             |> Paco.Stream.parse(lit("aaa"))
             |> Enum.to_list

    assert result == []
  end
end
