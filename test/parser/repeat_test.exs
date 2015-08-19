defmodule Paco.Parser.RepeatTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse" do
    assert parse("aaa", repeat(lit("a"), 0)) == {:ok, []}
    assert parse("aaa", repeat(lit("a"), 1)) == {:ok, ["a"]}
    assert parse("aaa", repeat(lit("a"), 2)) == {:ok, ["a", "a"]}

    assert parse("aaa", repeat(lit("a"), {2, 3})) == {:ok, ["a", "a", "a"]}

    assert parse("aaa", repeat(lit("a"), less_than: 2)) == {:ok, ["a"]}
    assert parse("aaa", repeat(lit("a"), more_than: 2)) == {:ok, ["a", "a", "a"]}
    assert parse("aaa", repeat(lit("a"), at_most: 2)) == {:ok, ["a", "a"]}
    assert parse("aaa", repeat(lit("a"), at_least: 2)) == {:ok, ["a", "a", "a"]}

    assert parse("", repeat(lit("a"))) == {:ok, []}
    assert parse("a", repeat(lit("a"))) == {:ok, ["a"]}
    assert parse("aa", repeat(lit("a"))) == {:ok, ["a", "a"]}
    assert parse("aaa", repeat(lit("a"))) == {:ok, ["a", "a", "a"]}
  end

  test "correctly advance the position position" do
    parser = repeat(lit("ab"))
    success = parse("abab", parser, format: :raw)
    assert success.from == {0, 1, 1}
    assert success.to == {3, 1, 4}
    assert success.at == {4, 1, 5}
    assert success.tail == ""
  end

  test "repeat and skip" do
    assert parse("aaa", repeat(skip(lit("a")))) == {:ok, []}
    assert parse("abab", repeat(one_of([skip(lit("a")), lit("b")]))) == {:ok, ["b", "b"]}
    assert parse("ababa", repeat(one_of([skip(lit("a")), lit("b")]))) == {:ok, ["b", "b"]}
  end

  test "boxing" do
    assert parse("aaa", repeat("a")) == {:ok, ["a", "a", "a"]}
    assert parse("aaa", repeat({"a"})) == {:ok, [{"a"}, {"a"}, {"a"}]}
  end

  test "fail to parse because it fails to match an exact number of times" do
    assert parse("ab", repeat(lit("a"), 2)) == {:error,
      ~s|expected "a" at 1:2 but got "b"|
    }
    assert parse("a", repeat(lit("a"), 2)) == {:error,
      ~s|expected "a" at 1:2 but got the end of input|
    }
  end

  test "fail to parse because it fails to match a mininum number of times" do
    assert parse("ab", repeat(lit("a"), at_least: 2)) == {:error,
      ~s|expected "a" at 1:2 but got "b"|
    }
    assert parse("a", repeat(lit("a"), at_least: 2)) == {:error,
      ~s|expected "a" at 1:2 but got the end of input|
    }
  end

  test "failure with description" do
    parser = repeat(lit("a"), 2) |> as("REPEAT")
    assert parse("ab", parser) == {:error,
      ~s|expected "a" (REPEAT) at 1:2 but got "b"|
    }
  end

  test "sugar combinators failure" do
    assert parse("ab", lit("a") |> exactly(2)) == {:error,
      ~s|expected "a" at 1:2 but got "b"|
    }
    assert parse("ab", lit("a") |> at_least(2)) == {:error,
      ~s|expected "a" at 1:2 but got "b"|
    }
    assert parse("bb", lit("a") |> one_or_more) == {:error,
      ~s|expected "a" at 1:1 but got "b"|
    }
    assert parse("aaabbb", lit("a") |> exactly(5)) == {:error,
      ~s|expected "a" at 1:4 but got "b"|
    }
  end

  test "cut creates fatal failures" do
    without_cut = repeat(sequence_of([lit("a"), lit("b")]))
    assert parse("ab", without_cut) == {:ok, [["a", "b"]]}
    assert parse("aba", without_cut) == {:ok, [["a", "b"]]}

    with_cut = repeat(sequence_of([lit("a"), cut, lit("b")]))
    assert parse("ab", with_cut) == {:ok, [["a", "b"]]}
    assert parse("aba", with_cut) == {:error,
      ~s|expected "b" at 1:4 but got the end of input|
    }
  end

  test "consumes input on success" do
    parser = repeat(lit("a"))
    success = parser.parse.(Paco.State.from("aab"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {1, 1, 2}
    assert success.at == {2, 1, 3}
    assert success.tail == "b"
  end

  test "doesn't consume input on empty success" do
    parser = repeat(lit("a"))
    success = parser.parse.(Paco.State.from("bbb"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
    assert success.at == {0, 1, 1}
    assert success.tail == "bbb"
  end

  test "doesn't consume input on failure" do
    parser = repeat(lit("a"), at_least: 1)
    failure = parser.parse.(Paco.State.from("bbb"), parser)
    assert failure.at == {0, 1, 1}
    assert failure.tail == "bbb"
  end
end
