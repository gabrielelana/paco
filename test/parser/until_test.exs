defmodule Paco.Parser.UntilTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "parse until boundary" do
    assert parse(until("c"), "abc") == {:ok, "ab"}
    assert parse(until("c"), "abcb") == {:ok, "ab"}
  end

  test "parse until boundary with escape" do
    assert parse(until("c", escaped_with: "\\"), "ab\\cdce") == {:ok, "abcd"}
  end

  test "parse until boundary with escape keeping escpe" do
    parser = until("c", escaped_with: "\\", keep_escape: true)
    assert parse(parser, "ab\\cdce") == {:ok, "ab\\cd"}
  end

  test "parse until multiple boundaries" do
    assert parse(until(["c"]), "abc") == {:ok, "ab"}
    assert parse(until(["c", "d"]), "abdcb") == {:ok, "ab"}
    assert parse(until(["c", "d", "b"]), "abdcb") == {:ok, "a"}
  end

  test "parse until multiple boundaries with escape" do
    assert parse(until([{"c", "\\"}]), "a\\cbcde") == {:ok, "acb"}
    assert parse(until(["c"], escaped_with: "\\"), "a\\cbcde") == {:ok, "acb"}

    assert parse(until([{"c", "\\"}, {"d", "\\"}]), "a\\c\\dc") == {:ok, "acd"}
    assert parse(until(["c", "d"], escaped_with: "\\"), "a\\c\\dc") == {:ok, "acd"}

    assert parse(until([{"c", "\\"}, {"d", "#"}]), "a\\c#dc") == {:ok, "acd"}
    assert parse(until(["c", {"d", "#"}], escaped_with: "\\"), "a\\c#dd") == {:ok, "acd"}
  end

  test "parse until multiple boundaries with escape keeping escape" do
    ke = [keep_escape: true]
    eke = [escaped_with: "\\", keep_escape: true]

    assert parse(until([{"c", "\\"}], ke), "a\\cbcde") == {:ok, "a\\cb"}
    assert parse(until(["c"], eke), "a\\cbcde") == {:ok, "a\\cb"}

    assert parse(until([{"c", "\\"}, {"d", "\\"}], ke), "a\\c\\dc") == {:ok, "a\\c\\d"}
    assert parse(until(["c", "d"], eke), "a\\c\\dc") == {:ok, "a\\c\\d"}

    assert parse(until([{"c", "\\"}, {"d", "#"}], ke), "a\\c#dc") == {:ok, "a\\c#d"}
    assert parse(until(["c", {"d", "#"}], eke), "a\\c#dd") == {:ok, "a\\c#d"}
  end

  test "failure when missing boundary" do
    assert parse(until("c"), "aaa") == {:error,
      ~s|expected something ended by "c" at 1:1 but got "aaa"|
    }
  end

  test "failure when missing boundary with escape" do
    assert parse(until("c", escaped_with: "\\"), "a\\ca") == {:error,
      ~S|expected something ended by "c" at 1:1 but got "a\ca"|
    }
  end

  test "failure when missing boundaries" do
    assert parse(until(["c", "d"]), "aaa") == {:error,
      ~s|expected something ended by one of ["c", "d"] at 1:1 but got "aaa"|
    }
  end

  test "failure when missing boundaries with escape" do
    assert parse(until(["c", "d"], escaped_with: "\\"), "a\\ca") == {:error,
      ~S|expected something ended by one of ["c", "d"] at 1:1 but got "a\ca"|
    }
  end

  test "failure with description" do
    parser = until("c") |> as("TOKEN")
    assert parse(parser, "aaa") == {:error,
      ~s|expected something ended by "c" (TOKEN) at 1:1 but got "aaa"|
    }
  end

  test "failure truncate tail when it's too long" do
    parser = until("c")

    long_text = String.duplicate("a", 1_000)
    assert parse(parser, long_text) == {:error,
      ~s|expected something ended by "c" at 1:1 but got "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa..."|
    }

    long_text = "aaa\n" <> String.duplicate("a", 1_000)
    assert parse(parser, long_text) == {:error,
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
