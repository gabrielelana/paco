defmodule Paco.Parser.RepeatTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse" do
    assert parse(repeat(lit("a"), 0), "aaa") == {:ok, []}
    assert parse(repeat(lit("a"), 1), "aaa") == {:ok, ["a"]}
    assert parse(repeat(lit("a"), 2), "aaa") == {:ok, ["a", "a"]}

    assert parse(repeat(lit("a"), {2, 3}), "aaa") == {:ok, ["a", "a", "a"]}

    assert parse(repeat(lit("a"), less_than: 2), "aaa") == {:ok, ["a"]}
    assert parse(repeat(lit("a"), more_than: 2), "aaa") == {:ok, ["a", "a", "a"]}
    assert parse(repeat(lit("a"), at_most: 2), "aaa") == {:ok, ["a", "a"]}
    assert parse(repeat(lit("a"), at_least: 2), "aaa") == {:ok, ["a", "a", "a"]}

    assert parse(repeat(lit("a")), "") == {:ok, []}
    assert parse(repeat(lit("a")), "a") == {:ok, ["a"]}
    assert parse(repeat(lit("a")), "aa") == {:ok, ["a", "a"]}
    assert parse(repeat(lit("a")), "aaa") == {:ok, ["a", "a", "a"]}
  end

  test "correctly advance the position position" do
    parser = repeat(lit("ab"))
    success = parse(parser, "abab", format: :raw)
    assert success.from == {0, 1, 1}
    assert success.to == {3, 1, 4}
    assert success.at == {4, 1, 5}
    assert success.tail == ""
  end

  test "repeat and skip" do
    assert parse(repeat(skip(lit("a"))), "aaa") == parse(skip(repeat(lit("a"))), "aaa")
  end

  test "boxing" do
    assert parse(repeat("a"), "aaa") == {:ok, ["a", "a", "a"]}
    assert parse(repeat({"a"}), "aaa") == {:ok, [{"a"}, {"a"}, {"a"}]}
  end

  test "fail to parse because it fails to match an exact number of times" do
    assert parse(repeat(lit("a"), 2), "ab") == {:error,
      ~s|expected "a" at 1:2 but got "b"|
    }
    assert parse(repeat(lit("a"), 2), "a") == {:error,
      ~s|expected "a" at 1:2 but got the end of input|
    }
  end

  test "fail to parse because it fails to match a mininum number of times" do
    assert parse(repeat(lit("a"), at_least: 2), "ab") == {:error,
      ~s|expected "a" at 1:2 but got "b"|
    }
    assert parse(repeat(lit("a"), at_least: 2), "a") == {:error,
      ~s|expected "a" at 1:2 but got the end of input|
    }
  end

  test "failure with description" do
    parser = repeat(lit("a"), 2) |> as("REPEAT")
    assert parse(parser, "ab") == {:error,
      ~s|expected "a" (REPEAT) at 1:2 but got "b"|
    }
  end

  test "sugar combinators failure" do
    assert parse(lit("a") |> exactly(2), "ab") == {:error,
      ~s|expected "a" at 1:2 but got "b"|
    }
    assert parse(lit("a") |> at_least(2), "ab") == {:error,
      ~s|expected "a" at 1:2 but got "b"|
    }
    assert parse(lit("a") |> one_or_more, "bb") == {:error,
      ~s|expected "a" at 1:1 but got "b"|
    }
    assert parse(lit("a") |> exactly(5), "aaabbb") == {:error,
      ~s|expected "a" at 1:4 but got "b"|
    }
  end

  test "cut creates fatal failures" do
    without_cut = repeat(sequence_of([lit("a"), lit("b")]))
    assert parse(without_cut, "ab") == {:ok, [["a", "b"]]}
    assert parse(without_cut, "aba") == {:ok, [["a", "b"]]}

    with_cut = repeat(sequence_of([lit("a"), cut, lit("b")]))
    assert parse(with_cut, "ab") == {:ok, [["a", "b"]]}
    assert parse(with_cut, "aba") == {:error,
      ~s|expected "b" at 1:4 but got the end of input|
    }
  end

  test "cut is not propagated to the next repetition" do
    before_cut = repeat(sequence_of([lit("a"), lit("b"), cut, lit("c")]))

    assert parse(before_cut, "abc") == {:ok, [["a", "b", "c"]]}
    assert parse(before_cut, "abca") == {:ok, [["a", "b", "c"]]}
    assert parse(before_cut, "abcab") == {:error,
      ~s|expected "c" at 1:6 but got the end of input|
    }
  end
end
