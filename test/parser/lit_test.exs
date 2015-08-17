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

  test "boxing" do
    assert parse("aaa", "aaa") == {:ok, "aaa"}
  end

  test "failure" do
    assert parse(lit("aaa"), "bbb") == {:error, ~s|expected "aaa" at 1:1 but got "bbb"|}
    assert parse(lit("aaa"), "aa") == {:error, ~s|expected "aaa" at 1:1 but got "aa"|}
    assert parse(lit("a"), "bbb") == {:error, ~s|expected "a" at 1:1 but got "b"|}
  end

  test "failure for end of input" do
    assert parse(lit("aaa"), "") == {:error, ~s|expected "aaa" at 1:1 but got the end of input|}
  end

  test "failure with description" do
    parser = lit("aaa") |> as("A")
    assert parse(parser, "") == {:error, ~s|expected "aaa" (A) at 1:1 but got the end of input|}
  end

  test "failure keeps only relevant part of the tail" do
    parser = lit("aaa")
    assert parse(parser, "xxxyyy") == {:error, ~s|expected "aaa" at 1:1 but got "xxx"|}
  end

  test "failure has rank" do
    parser = lit("aaa")

    f1 = parser.parse.(Paco.State.from("bbb"), parser)
    f2 = parser.parse.(Paco.State.from("abb"), parser)
    f3 = parser.parse.(Paco.State.from("aab"), parser)

    assert f1.rank < f2.rank
    assert f2.rank < f3.rank
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
