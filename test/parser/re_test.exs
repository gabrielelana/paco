defmodule Paco.Parser.RegexTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "parse regular expression" do
    assert parse(re(~r/a+/), "a") == {:ok, "a"}
    assert parse(re(~r/a+/), "aa") == {:ok, "aa"}
    assert parse(re(~r/a+/), "aaa") == {:ok, "aaa"}
  end

  test "parse regular expression with captures" do
    assert parse(re(~r/c(a+)/), "ca") == {:ok, {"ca", ["a"]}}
    # repeated subpatterns are not supported by regular expressions
    assert parse(re(~r/c(a|b)+/), "cab") == {:ok, {"cab", ["b"]}}
    assert parse(re(~r/c(a+)(b+)/), "caaabbb") == {:ok, {"caaabbb", ["aaa", "bbb"]}}
    assert parse(re(~r/c(a+)(b*)/), "caaa") == {:ok, {"caaa", ["aaa", ""]}}
  end

  test "parse regular expression with named captures" do
    assert parse(re(~r/c(?<N>a+)/), "ca") == {:ok, {"ca", %{"N" => "a"}}}
    assert parse(re(~r/c(?<N>a+)/), "caaa") == {:ok, {"caaa", %{"N" => "aaa"}}}
    # repeated subpatterns are not supported by regular expressions
    assert parse(re(~r/c(?<N>a|b)+/), "cab") == {:ok, {"cab", %{"N" => "b"}}}
    assert parse(re(~r/c(?<N>a+)(?<M>b+)/), "cab") == {:ok, {"cab", %{"N" => "a", "M" => "b"}}}
  end

  test "parse regular expression with mixed captures" do
    # TODO
    # assert parse(re(~r/c(?<N>a)(b)/), "cab") == {:ok, {"cab", ["b"], %{"N" => "a"}}}
  end

  test "patterns are anchored at the beginning of the text" do
    assert {:error, _} = parse(re(~r/a+/), "baaa")
    assert {:error, _} = parse(re(~r/.*a+/), "b\naaa")
    assert {:ok, _}    = parse(re(~r/.*\na+/m), "b\naaa")
    assert {:error, _} = parse(re(~r/\Aa+/), "baaa")
  end

  test "failure" do
    assert parse(re(~r/a+/), "b") == {:error, ~s|expected ~r/a+/ at 1:1 but got "b"|}
  end

  test "failure with description" do
    parser = re(~r/a+/) |> as("TOKEN")
    assert parse(parser, "b") == {:error, ~s|expected ~r/a+/ (TOKEN) at 1:1 but got "b"|}
  end

  test "increment indexes for a match" do
    parser = re(~r/a+/)
    success = parser.parse.(Paco.State.from("aaabbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {2, 1, 3}
    assert success.at == {3, 1, 4}
    assert success.tail == [{success.at, "bbb"}]
  end

  test "increment indexes for a match with newlines" do
    parser = re(~r/(?:a\n)+/m)
    success = parser.parse.(Paco.State.from("a\na\na\nbbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {5, 3, 2}
    assert success.at == {6, 4, 1}
    assert success.tail == [{success.at, "bbb"}]
  end

  test "increment indexes for a match with captures" do
    parser = re(~r/(a+)/m)
    success = parser.parse.(Paco.State.from("aaabbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {2, 1, 3}
    assert success.at == {3, 1, 4}
    assert success.tail == [{success.at, "bbb"}]
  end

  test "increment indexes for a single character match" do
    parser = re(~r/a/)
    success = parser.parse.(Paco.State.from("aaabbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
    assert success.at == {1, 1, 2}
    assert success.tail == [{success.at, "aabbb"}]
  end

  test "increment indexes for an empty match" do
    parser = re(~r/a*/)
    success = parser.parse.(Paco.State.from("bbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
    assert success.at == {0, 1, 1}
    assert success.tail == [{success.at, "bbb"}]
  end

  test "increment indexes for a failure" do
    parser = re(~r/a+/)
    failure = parser.parse.(Paco.State.from("bb"), parser)
    assert failure.at == {0, 1, 1}
    assert failure.tail == [{failure.at, "bb"}]
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
