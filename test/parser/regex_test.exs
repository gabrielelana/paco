defmodule Paco.Parser.RegexTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "parse" do
    assert parse(regex(~r/a+/), "a") == {:ok, "a"}
    assert parse(regex(~r/a+/), "aa") == {:ok, "aa"}
    assert parse(regex(~r/a+/), "aaa") == {:ok, "aaa"}
  end

  test "from" do
    assert %Paco.Parser{name: "regex"} = from(~r/a+/)
    assert %Paco.Parser{name: "regex"} = from(~R/a+/)
  end

  test "parse with captures" do
    assert parse(regex(~r/c(a+)/), "ca") == {:ok, ["ca", "a"]}
    # repeated subpatterns are not supported by regular expressions
    assert parse(regex(~r/c(a)+/), "caa") == {:ok, ["caa", "a"]}
    assert parse(regex(~r/c(a+)(b+)/), "caaabbb") == {:ok, ["caaabbb", "aaa", "bbb"]}
    assert parse(regex(~r/c(a+)(b*)/), "caaa") == {:ok, ["caaa", "aaa", ""]}
  end

  test "parse with named captures" do
    assert parse(regex(~r/c(?<As>a+)/), "ca") == {:ok, ["ca", %{"As" => "a"}]}
    assert parse(regex(~r/c(?<As>a+)/), "caaa") == {:ok, ["caaa", %{"As" => "aaa"}]}
    # repeated subpatterns are not supported by regular expressions
    assert parse(regex(~r/c(?<As>a)+/), "caaa") == {:ok, ["caaa", %{"As" => "a"}]}
    assert parse(regex(~r/c(?<As>a+)(?<Bs>b+)/), "cab") == {:ok, ["cab", %{"As" => "a", "Bs" => "b"}]}
  end

  test "patterns are anchored at the beginning of the text" do
    assert {:error, _} = parse(regex(~r/a+/), "baaa")
    assert {:error, _} = parse(regex(~r/.*a+/), "b\naaa")
    assert {:ok, _}    = parse(regex(~r/.*\na+/m), "b\naaa")
    assert {:error, _} = parse(regex(~r/\Aa+/), "baaa")
  end

  test "describe" do
    assert describe(regex(~r/a+/)) == "regex(~r/a+/)"
    assert describe(regex(~r/a+/i)) == "regex(~r/a+/i)"
    assert describe(regex(~r/a+/i, wait_for: 1_000)) == "regex(~r/a+/i)"
  end

  test "failure" do
    assert parse(regex(~r/a+/), "b") == {:error,
      """
      Failed to match regex(~r/a+/) at 1:1
      """
    }
  end

  test "wait for more state in stream mode" do
    [result] = Helper.stream_of("aaab")
             |> Paco.Stream.parse(regex(~r/a+b/))
             |> Enum.to_list

    assert result == "aaab"
  end

  test "don't wait for more state if we have enough" do
    results = Helper.stream_of("aaa")
             |> Paco.Stream.parse(regex(~r/a+/))
             |> Enum.to_list

    assert results == ["a", "a", "a"]
  end

  test "don't wait for more state in stream mode when state is enough" do
    # we are telling the parser to wait for 3 characters before giving up
    # return a failure, since 3 characters are not enough (given the state)
    # to make the parser succeed then the parser fails
    result = Helper.stream_of("aaab")
             |> Paco.Stream.parse(regex(~r/a+b/, wait_for: 3))
             |> Enum.to_list

    assert result == []
  end

  test "notify events on success" do
    assert Helper.events_notified_by(regex(~r/a+/), "aaa") == [
      {:loaded, "aaa"},
      {:started, "regex(~r/a+/)"},
      {:matched, {0, 1, 1}, {2, 1, 3}, {3, 1, 4}},
    ]
  end

  test "notify events on failure" do
    assert Helper.events_notified_by(regex(~r/b+/), "aaa") == [
      {:loaded, "aaa"},
      {:started, "regex(~r/b+/)"},
      {:failed, {0, 1, 1}},
    ]
  end

  test "increment indexes for a match" do
    parser = regex(~r/a+/)
    success = parser.parse.(Paco.State.from("aaabbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {2, 1, 3}
    assert success.at == {3, 1, 4}
    assert success.tail == "bbb"
  end

  test "increment indexes for a match with newlines" do
    parser = regex(~r/(?:a\n)+/m)
    success = parser.parse.(Paco.State.from("a\na\na\nbbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {5, 3, 2}
    assert success.at == {6, 4, 1}
    assert success.tail == "bbb"
  end

  test "increment indexes for a match with captures" do
    parser = regex(~r/(a+)/m)
    success = parser.parse.(Paco.State.from("aaabbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {2, 1, 3}
    assert success.at == {3, 1, 4}
    assert success.tail == "bbb"
  end

  test "increment indexes for a single character match" do
    parser = regex(~r/a/)
    success = parser.parse.(Paco.State.from("aaabbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
    assert success.at == {1, 1, 2}
    assert success.tail == "aabbb"
  end

  test "increment indexes for an empty match" do
    parser = regex(~r/a*/)
    success = parser.parse.(Paco.State.from("bbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
    assert success.at == {0, 1, 1}
    assert success.tail == "bbb"
  end
end
