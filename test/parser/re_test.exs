defmodule Paco.Parser.RegexTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "parse" do
    assert parse(re(~r/a+/), "a") == {:ok, "a"}
    assert parse(re(~r/a+/), "aa") == {:ok, "aa"}
    assert parse(re(~r/a+/), "aaa") == {:ok, "aaa"}
  end

  test "from" do
    assert %Paco.Parser{name: "re"} = from(~r/a+/)
    assert %Paco.Parser{name: "re"} = from(~R/a+/)
  end

  test "parse with captures" do
    assert parse(re(~r/c(a+)/), "ca") == {:ok, ["ca", "a"]}
    # repeated subpatterns are not supported by regular expressions
    assert parse(re(~r/c(a)+/), "caa") == {:ok, ["caa", "a"]}
    assert parse(re(~r/c(a+)(b+)/), "caaabbb") == {:ok, ["caaabbb", "aaa", "bbb"]}
    assert parse(re(~r/c(a+)(b*)/), "caaa") == {:ok, ["caaa", "aaa", ""]}
  end

  test "parse with named captures" do
    assert parse(re(~r/c(?<As>a+)/), "ca") == {:ok, ["ca", %{"As" => "a"}]}
    assert parse(re(~r/c(?<As>a+)/), "caaa") == {:ok, ["caaa", %{"As" => "aaa"}]}
    # repeated subpatterns are not supported by regular expressions
    assert parse(re(~r/c(?<As>a)+/), "caaa") == {:ok, ["caaa", %{"As" => "a"}]}
    assert parse(re(~r/c(?<As>a+)(?<Bs>b+)/), "cab") == {:ok, ["cab", %{"As" => "a", "Bs" => "b"}]}
  end

  test "patterns are anchored at the beginning of the text" do
    assert {:error, _} = parse(re(~r/a+/), "baaa")
    assert {:error, _} = parse(re(~r/.*a+/), "b\naaa")
    assert {:ok, _}    = parse(re(~r/.*\na+/m), "b\naaa")
    assert {:error, _} = parse(re(~r/\Aa+/), "baaa")
  end

  test "describe" do
    assert describe(re(~r/a+/)) == "re#1(~r/a+/, [])"
    assert describe(re(~r/a+/i)) == "re#2(~r/a+/i, [])"
    assert describe(re(~r/a+/i, wait_for: 1_000)) == "re#3(~r/a+/i, [wait_for: 1000])"
  end

  test "failure" do
    assert parse(re(~r/a+/), "b") == {:error,
      """
      Failed to match re#1(~r/a+/, []) at 1:1
      """
    }
  end

  test "notify events on success" do
    Helper.assert_events_notified(re(~r/a+/), "aaa", [
      {:started, "re#1(~r/a+/, [])"},
      {:matched, {0, 1, 1}, {2, 1, 3}, {3, 1, 4}},
    ])
  end

  test "notify events on failure" do
    Helper.assert_events_notified(re(~r/b+/), "aaa", [
      {:started, "re#1(~r/b+/, [])"},
      {:failed, {0, 1, 1}},
    ])
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

  test "do not consume input with a failure" do
    parser = re(~r/a+/)
    failure = parser.parse.(Paco.State.from("bb"), parser)
    assert failure.at == {0, 1, 1}
    assert failure.tail == "bb"
  end

  test "stream mode success" do
    result = Helper.stream_of("aaab")
             |> Paco.Stream.parse(re(~r/a+/))
             |> Enum.to_list

    assert result == ["aaa"]
  end

  test "stream mode success at the end of input" do
    result = Helper.stream_of("aaa")
             |> Paco.Stream.parse(re(~r/a+/))
             |> Enum.to_list

    assert result == ["aaa"]
  end

  test "stream mode failure" do
    result = Helper.stream_of("bbb")
             |> Paco.Stream.parse(re(~r/a+/))
             |> Enum.to_list

    assert result == []
  end

  test "stream mode failure because of the end of input" do
    result = Helper.stream_of("aa")
             |> Paco.Stream.parse(re(~r/a{3}/))
             |> Enum.to_list

    assert result == []
  end

  test "stream mode failure because it doesn't consume any input" do
    result = Helper.stream_of("bbb")
             |> Paco.Stream.parse(re(~r/a*/), on_failure: :yield)
             |> Enum.to_list

    assert result == [{:error,
      """
      Failed to match re#1(~r/a*/, []) at 1:1, because it didn't consume any input
      """
    }]
  end

  test "stream mode for an empty input" do
    result = [""]
             |> Paco.Stream.parse(re(~r/a+/))
             |> Enum.to_list

    assert result == []
  end

  test "don't wait for more text in stream mode when initial text is enough" do
    # we are telling the parser to wait for 3 characters before giving up
    # return a failure, since 3 characters are not enough to make the parser
    # succeed then the parser fails
    result = Helper.stream_of("aaab")
             |> Paco.Stream.parse(re(~r/a+b/, wait_for: 3))
             |> Enum.to_list

    assert result == []
  end
end
