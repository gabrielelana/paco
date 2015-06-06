defmodule Paco.Parser.RegexTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "parse" do
    assert parse(rex(~r/a+/), "a") == {:ok, "a"}
    assert parse(rex(~r/a+/), "aa") == {:ok, "aa"}
    assert parse(rex(~r/a+/), "aaa") == {:ok, "aaa"}
  end

  test "parse with captures" do
    assert parse(rex(~r/c(a+)/), "ca") == {:ok, ["ca", "a"]}
    # repeated subpatterns are not supported by regular expressions
    assert parse(rex(~r/c(a)+/), "caa") == {:ok, ["caa", "a"]}
    assert parse(rex(~r/c(a+)(b+)/), "caaabbb") == {:ok, ["caaabbb", "aaa", "bbb"]}
    assert parse(rex(~r/c(a+)(b*)/), "caaa") == {:ok, ["caaa", "aaa", ""]}
  end

  test "parse with named captures" do
    assert parse(rex(~r/c(?<As>a+)/), "ca") == {:ok, ["ca", %{"As" => "a"}]}
    assert parse(rex(~r/c(?<As>a+)/), "caaa") == {:ok, ["caaa", %{"As" => "aaa"}]}
    # repeated subpatterns are not supported by regular expressions
    assert parse(rex(~r/c(?<As>a)+/), "caaa") == {:ok, ["caaa", %{"As" => "a"}]}
    assert parse(rex(~r/c(?<As>a+)(?<Bs>b+)/), "cab") == {:ok, ["cab", %{"As" => "a", "Bs" => "b"}]}
  end

  test "patterns are anchored at the beginning of the text" do
    assert {:error, _} = parse(rex(~r/a+/), "baaa")
    assert {:error, _} = parse(rex(~r/.*a+/), "b\naaa")
    assert {:ok, _}    = parse(rex(~r/.*\na+/m), "b\naaa")
    assert {:error, _} = parse(rex(~r/\Aa+/), "baaa")
  end

  test "describe" do
    assert describe(rex(~r/a+/)) == "rex(~r/a+/)"
    assert describe(rex(~r/a+/i)) == "rex(~r/a+/i)"
  end

  test "failure" do
    assert parse(rex(~r/a+/), "b") == {:error,
      """
      Failed to match rex(~r/a+/) at 1:1
      """
    }
  end

  test "increment indexes for a match" do
    parser = rex(~r/a+/)
    success = parser.parse.(Paco.State.from("aaabbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {2, 1, 3}
    assert success.at == {3, 1, 4}
    assert success.tail == "bbb"
  end

  test "increment indexes for a match with newlines" do
    parser = rex(~r/(?:a\n)+/m)
    success = parser.parse.(Paco.State.from("a\na\na\nbbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {5, 3, 2}
    assert success.at == {6, 4, 1}
    assert success.tail == "bbb"
  end

  test "increment indexes for a match with captures" do
    parser = rex(~r/(a+)/m)
    success = parser.parse.(Paco.State.from("aaabbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {2, 1, 3}
    assert success.at == {3, 1, 4}
    assert success.tail == "bbb"
  end

  test "increment indexes for a single character match" do
    parser = rex(~r/a/)
    success = parser.parse.(Paco.State.from("aaabbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
    assert success.at == {1, 1, 2}
    assert success.tail == "aabbb"
  end

  test "increment indexes for an empty match" do
    parser = rex(~r/a*/)
    success = parser.parse.(Paco.State.from("bbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
    assert success.at == {0, 1, 1}
    assert success.tail == "bbb"
  end

  test "increment indexes for a failure" do
    parser = rex(~r/a+/)
    failure = parser.parse.(Paco.State.from("bb"), parser)
    assert failure.at == {0, 1, 1}
    assert failure.tail == "bb"
  end

  test "stream mode success" do
    for stream <- Helper.streams_of("aaab") do
      result = stream
               |> Paco.Stream.parse(rex(~r/a+/))
               |> Enum.to_list

      assert result == ["aaa"]
    end
  end

  test "stream mode success at the end of input" do
    for stream <- Helper.streams_of("aaa") do
      result = stream
               |> Paco.Stream.parse(rex(~r/a+/))
               |> Enum.to_list

      assert result == ["aaa"]
    end
  end

  test "stream mode failure" do
    for stream <- Helper.streams_of("bbb") do
      result = stream
               |> Paco.Stream.parse(rex(~r/a+/))
               |> Enum.to_list

      assert result == []
    end
  end

  test "stream mode failure because of the end of input" do
    for stream <- Helper.streams_of("aa") do
      result = stream
               |> Paco.Stream.parse(rex(~r/a{3}/))
               |> Enum.to_list

      assert result == []
    end
  end

  test "stream mode failure because it doesn't consume any input" do
    parser = rex(~r/a*/)
    for stream <- Helper.streams_of("bbb") do
      result = stream
               |> Paco.Stream.parse(parser, on_failure: :yield)
               |> Enum.to_list

      assert result == [{:error,
        """
        Failed to match rex(~r/a*/) at 1:1, \
        because it didn't consume any input
        """
      }]
    end
  end

  test "stream mode for an empty input" do
    for stream <- Helper.streams_of(["", ""]) do
      result = stream
               |> Paco.Stream.parse(rex(~r/a+/))
               |> Enum.to_list

      assert result == []
    end
  end
end
