defmodule Paco.Parser.RegexTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "parse regular expression" do
    assert parse("a", re(~r/a+/)) == {:ok, "a"}
    assert parse("aa", re(~r/a+/)) == {:ok, "aa"}
    assert parse("aaa", re(~r/a+/)) == {:ok, "aaa"}
  end

  test "parse regular expression with captures" do
    assert parse("ca", re(~r/c(a+)/)) == {:ok, {"ca", ["a"]}}
    # repeated subpatterns are not supported by regular expressions
    assert parse("cab", re(~r/c(a|b)+/)) == {:ok, {"cab", ["b"]}}
    assert parse("caaabbb", re(~r/c(a+)(b+)/)) == {:ok, {"caaabbb", ["aaa", "bbb"]}}
    assert parse("caaa", re(~r/c(a+)(b*)/)) == {:ok, {"caaa", ["aaa", ""]}}
  end

  test "parse regular expression with named captures" do
    assert parse("ca", re(~r/c(?<N>a+)/)) == {:ok, {"ca", %{"N" => "a"}}}
    assert parse("caaa", re(~r/c(?<N>a+)/)) == {:ok, {"caaa", %{"N" => "aaa"}}}
    # repeated subpatterns are not supported by regular expressions
    assert parse("cab", re(~r/c(?<N>a|b)+/)) == {:ok, {"cab", %{"N" => "b"}}}
    assert parse("cab", re(~r/c(?<N>a+)(?<M>b+)/)) == {:ok, {"cab", %{"N" => "a", "M" => "b"}}}
  end

  test "parse regular expression with mixed captures" do
    # TODO
    # assert parse("cab", re(~r/c(?<N>a)(b)/)) == {:ok, {"cab", ["b"], %{"N" => "a"}}}
  end

  test "patterns are anchored at the beginning of the text" do
    assert {:error, _} = parse("baaa", re(~r/a+/))
    assert {:error, _} = parse("b\naaa", re(~r/.*a+/))
    assert {:ok, _}    = parse("b\naaa", re(~r/.*\na+/m))
    assert {:error, _} = parse("baaa", re(~r/\Aa+/))
  end

  test "failure" do
    assert parse("b", re(~r/a+/)) == {:error, ~s|expected ~r/a+/ at 1:1 but got "b"|}
  end

  test "failure with description" do
    parser = re(~r/a+/) |> as("TOKEN")
    assert parse("b", parser) == {:error, ~s|expected ~r/a+/ (TOKEN) at 1:1 but got "b"|}
  end

  test "increment indexes for a match" do
    parser = re(~r/a+/)
    success = parser.parse.(Paco.State.from("aaabbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {2, 1, 3}
    assert success.at == {3, 1, 4}
    assert success.tail == "bbb"
  end

  test "increment indexes for a match with newlines" do
    parser = re(~r/(?:a\n)+/m)
    success = parser.parse.(Paco.State.from("a\na\na\nbbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {5, 3, 2}
    assert success.at == {6, 4, 1}
    assert success.tail == "bbb"
  end

  test "increment indexes for a match with captures" do
    parser = re(~r/(a+)/m)
    success = parser.parse.(Paco.State.from("aaabbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {2, 1, 3}
    assert success.at == {3, 1, 4}
    assert success.tail == "bbb"
  end

  test "increment indexes for a single character match" do
    parser = re(~r/a/)
    success = parser.parse.(Paco.State.from("aaabbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
    assert success.at == {1, 1, 2}
    assert success.tail == "aabbb"
  end

  test "increment indexes for an empty match" do
    parser = re(~r/a*/)
    success = parser.parse.(Paco.State.from("bbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
    assert success.at == {0, 1, 1}
    assert success.tail == "bbb"
  end

  test "increment indexes for a failure" do
    parser = re(~r/a+/)
    failure = parser.parse.(Paco.State.from("bb"), parser)
    assert failure.at == {0, 1, 1}
    assert failure.tail == "bb"
  end

  test "stream mode success" do
    for stream <- Helper.streams_of("aaab") do
      result = stream
               |> Paco.Stream.parse(re(~r/a+/))
               |> Enum.to_list

      assert result == ["aaa"]
    end
  end

  test "stream mode success at the end of input" do
    for stream <- Helper.streams_of("aaa") do
      result = stream
               |> Paco.Stream.parse(re(~r/a+/))
               |> Enum.to_list

      assert result == ["aaa"]
    end
  end

  test "stream mode failure" do
    for stream <- Helper.streams_of("bbb") do
      result = stream
               |> Paco.Stream.parse(re(~r/a+/))
               |> Enum.to_list

      assert result == []
    end
  end

  test "stream mode failure because of the end of input" do
    for stream <- Helper.streams_of("aa") do
      result = stream
               |> Paco.Stream.parse(re(~r/a{3}/))
               |> Enum.to_list

      assert result == []
    end
  end

  test "stream mode failure because it doesn't consume any input" do
    parser = re(~r/a*/)
    for stream <- Helper.streams_of("bbb") do
      result = stream
               |> Paco.Stream.parse(parser, on_failure: :yield)
               |> Enum.to_list

      assert result == [{:error, ~s|failure! parser didn't consume any input|}]
    end
  end

  test "stream mode for an empty input" do
    for stream <- Helper.streams_of(["", ""]) do
      result = stream
               |> Paco.Stream.parse(re(~r/a+/))
               |> Enum.to_list

      assert result == []
    end
  end
end
