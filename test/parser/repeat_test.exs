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

  test "boxing" do
    assert parse(repeat("a"), "aaa") == {:ok, ["a", "a", "a"]}
    assert parse(repeat({"a"}), "aaa") == {:ok, [{"a"}, {"a"}, {"a"}]}
  end

  test "fail to parse because it fails to match an exact number of times" do
    assert parse(repeat(lit("a"), 2), "ab") == {:error,
      ~s|expected 1 more "a" at 1:2 but got "b"|
    }
    assert parse(repeat(lit("a"), 2), "a") == {:error,
      ~s|expected 1 more "a" at 1:2 but got the end of input|
    }
  end

  test "fail to parse because it fails to match a mininum number of times" do
    assert parse(repeat(lit("a"), at_least: 2), "ab") == {:error,
      ~s|expected at least 1 more "a" at 1:2 but got "b"|
    }
    assert parse(repeat(lit("a"), at_least: 2), "a") == {:error,
      ~s|expected at least 1 more "a" at 1:2 but got the end of input|
    }
  end

  test "failure with description" do
    parser = repeat(lit("a"), 2) |> as("REPEAT")
    assert parse(parser, "ab") == {:error,
      ~s|expected 1 more "a" (REPEAT) at 1:2 but got "b"|
    }
  end

  test "sugar combinators failure" do
    assert parse(lit("a") |> exactly(2), "ab") == {:error,
      ~s|expected 1 more "a" at 1:2 but got "b"|
    }
    assert parse(lit("a") |> at_least(2), "ab") == {:error,
      ~s|expected at least 1 more "a" at 1:2 but got "b"|
    }
    assert parse(lit("a") |> one_or_more, "bb") == {:error,
      ~s|expected at least 1 "a" at 1:1 but got "b"|
    }
    assert parse(lit("a") |> exactly(5), "bbbbbxxx") == {:error,
      ~s|expected at least 5 "a" at 1:1 but got "bbbbb"|
    }
  end
end
