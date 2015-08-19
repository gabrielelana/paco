defmodule Paco.Parser.UntilTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "parse until boundary" do
    assert parse("abc", until("c")) == {:ok, "ab"}
    assert parse("abcb", until("c")) == {:ok, "ab"}
  end

  test "parse until boundary with escape" do
    assert parse("ab\\cdce", until("c", escaped_with: "\\")) == {:ok, "abcd"}
  end

  test "parse until boundary with escape keeping escpe" do
    parser = until("c", escaped_with: "\\", keep_escape: true)
    assert parse("ab\\cdce", parser) == {:ok, "ab\\cd"}
  end

  test "parse until eof" do
    assert parse("aaa", until("b", eof: true)) == {:ok, "aaa"}
  end

  test "parse until boundaries" do
    assert parse("abc", until(["c"])) == {:ok, "ab"}
    assert parse("abdcb", until(["c", "d"])) == {:ok, "ab"}
    assert parse("abdcb", until(["c", "d", "b"])) == {:ok, "a"}
  end

  test "parse until boundaries with escape" do
    assert parse("a\\cbcde", until([{"c", "\\"}])) == {:ok, "acb"}
    assert parse("a\\cbcde", until(["c"], escaped_with: "\\")) == {:ok, "acb"}

    assert parse("a\\c\\dc", until([{"c", "\\"}, {"d", "\\"}])) == {:ok, "acd"}
    assert parse("a\\c\\dc", until(["c", "d"], escaped_with: "\\")) == {:ok, "acd"}

    assert parse("a\\c#dc", until([{"c", "\\"}, {"d", "#"}])) == {:ok, "acd"}
    assert parse("a\\c#dd", until(["c", {"d", "#"}], escaped_with: "\\")) == {:ok, "acd"}
  end

  test "parse until boundaries with escape keeping escape" do
    ke = [keep_escape: true]
    eke = [escaped_with: "\\", keep_escape: true]

    assert parse("a\\cbcde", until([{"c", "\\"}], ke)) == {:ok, "a\\cb"}
    assert parse("a\\cbcde", until(["c"], eke)) == {:ok, "a\\cb"}

    assert parse("a\\c\\dc", until([{"c", "\\"}, {"d", "\\"}], ke)) == {:ok, "a\\c\\d"}
    assert parse("a\\c\\dc", until(["c", "d"], eke)) == {:ok, "a\\c\\d"}

    assert parse("a\\c#dc", until([{"c", "\\"}, {"d", "#"}], ke)) == {:ok, "a\\c#d"}
    assert parse("a\\c#dd", until(["c", {"d", "#"}], eke)) == {:ok, "a\\c#d"}
  end

  test "boundaries are flattened" do
    assert parse("aaae", until(["c", ["d", "e"]])) == {:ok, "aaa"}
    assert parse("a\\cae", until([{"c", "\\"}, ["d", "e"]])) == {:ok, "aca"}
    assert parse("a\\dae", until(["c", [{"d", "\\"}, "e"]])) == {:ok, "ada"}
    assert parse("a\\eae", until(["c", ["d", {"e", "\\"}]])) == {:ok, "aea"}
    assert parse("a\\cae", until(["c", ["d", "e"]], escaped_with: "\\")) == {:ok, "aca"}
    assert parse("a\\dae", until(["c", ["d", "e"]], escaped_with: "\\")) == {:ok, "ada"}
    assert parse("a\\eae", until(["c", ["d", "e"]], escaped_with: "\\")) == {:ok, "aea"}
  end

  test "failure when missing boundary" do
    assert parse("aaa", until("c")) == {:error,
      ~s|expected something ended by "c" at 1:1 but got "aaa"|
    }
  end

  test "failure when missing boundary with escape" do
    assert parse("a\\ca", until("c", escaped_with: "\\")) == {:error,
      ~S|expected something ended by "c" at 1:1 but got "a\ca"|
    }
  end

  test "failure when missing boundaries" do
    assert parse("aaa", until(["c", "d"])) == {:error,
      ~s|expected something ended by one of ["c", "d"] at 1:1 but got "aaa"|
    }
  end

  test "failure when missing boundaries with escape" do
    assert parse("a\\ca", until(["c", "d"], escaped_with: "\\")) == {:error,
      ~S|expected something ended by one of ["c", "d"] at 1:1 but got "a\ca"|
    }
  end

  test "failure with description" do
    parser = until("c") |> as("TOKEN")
    assert parse("aaa", parser) == {:error,
      ~s|expected something ended by "c" (TOKEN) at 1:1 but got "aaa"|
    }
  end

  test "failure truncate tail when it's too long" do
    parser = until("c")

    long_text = String.duplicate("a", 1_000)
    assert parse(long_text, parser) == {:error,
      """
      expected something ended by "c" at 1:1 but got \
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa..."\
      """
    }

    long_text = "aaa\n" <> String.duplicate("a", 1_000)
    assert parse(long_text, parser) == {:error,
      ~s|expected something ended by "c" at 1:1 but got "aaa"|
    }
  end

  test "failure has rank" do
    parser = until("c")

    f1 = parser.parse.(Paco.State.from("a"), parser)
    f2 = parser.parse.(Paco.State.from("aa"), parser)
    f3 = parser.parse.(Paco.State.from("aaa"), parser)

    assert f1.rank < f2.rank
    assert f2.rank < f3.rank
  end

  test "stream mode until a boundary" do
    for stream <- Helper.streams_of("aab") do
      result = stream
               |> Paco.Stream.parse(until("b"))
               |> Enum.to_list

      assert result == ["aa"]
    end
  end

  test "stream mode until a boundary with escape" do
    for stream <- Helper.streams_of("a\\bab") do
      result = stream
               |> Paco.Stream.parse(until("b", escaped_with: "\\"))
               |> Enum.to_list

      assert result == ["aba"]
    end
  end

  test "stream mode when missing boundary" do
    for stream <- Helper.streams_of("aa") do
      result = stream
               |> Paco.Stream.parse(until("b"))
               |> Enum.to_list

      assert result == []
    end
  end

  test "stream mode for an empty input" do
    result = [""]
             |> Paco.Stream.parse(until("b"))
             |> Enum.to_list

    assert result == []
  end
end
