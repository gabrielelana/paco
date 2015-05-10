defmodule Paco.Parser.ReTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse" do
    assert parse(re(~r/a+/), "a") == {:ok, "a"}
    assert parse(re(~r/a+/), "aa") == {:ok, "aa"}
    assert parse(re(~r/a+/), "aaa") == {:ok, "aaa"}
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
    assert describe(re(~r/a+/)) == "re(~r/a+/)"
    assert describe(re(~r/a+/i)) == "re(~r/a+/i)"
    assert describe(re(~r/a+/i, wait_for: 1_000)) == "re(~r/a+/i)"
  end

  test "failure" do
    assert {:error, failure} = parse(re(~r/a+/), "b")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match re(~r/a+/) at 1:1
      """
  end

  test "increment indexes for a match" do
    input = Paco.Input.from("aaabbb")
    parser = re(~r/a+/)
    success = parser.parse.(input, parser)
    assert success.from == {0, 1, 1}
    assert success.to == {2, 1, 3}
    assert success.at == {3, 1, 4}
    assert success.tail == "bbb"
  end

  test "increment indexes for a match with newlines" do
    input = Paco.Input.from("a\na\na\nbbb")
    parser = re(~r/(?:a\n)+/m)
    success = parser.parse.(input, parser)
    assert success.from == {0, 1, 1}
    assert success.to == {5, 3, 2}
    assert success.at == {6, 4, 1}
    assert success.tail == "bbb"
  end

  test "increment indexes for a match with captures" do
    input = Paco.Input.from("aaabbb")
    parser = re(~r/(a+)/m)
    success = parser.parse.(input, parser)
    assert success.from == {0, 1, 1}
    assert success.to == {2, 1, 3}
    assert success.at == {3, 1, 4}
    assert success.tail == "bbb"
  end

  test "increment indexes for a single character match" do
    input = Paco.Input.from("aaabbb")
    parser = re(~r/a/)
    success = parser.parse.(input, parser)
    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
    assert success.at == {1, 1, 2}
    assert success.tail == "aabbb"
  end

  test "increment indexes for an empty match" do
    input = Paco.Input.from("bbb")
    parser = re(~r/a*/)
    success = parser.parse.(input, parser)
    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
    assert success.at == {0, 1, 1}
    assert success.tail == "bbb"
  end

  # wait_for in stream mode
  # wait_for could be a function
  # notify events
  # anchoring
end
