defmodule Paco.Parser.RepeatTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse" do
    assert parse(repeat(lit("a"), 0), "aaa") == {:ok, []}
    assert parse(repeat(lit("a"), 1), "aaa") == {:ok, ["a"]}
    assert parse(repeat(lit("a"), 2), "aaa") == {:ok, ["a", "a"]}

    assert parse(repeat(lit("a"), {2, 3}), "aaa") == {:ok, ["a", "a", "a"]}

    assert parse(repeat(lit("a"), {:less_than, 2}), "aaa") == {:ok, ["a"]}
    assert parse(repeat(lit("a"), {:more_than, 2}), "aaa") == {:ok, ["a", "a", "a"]}
    assert parse(repeat(lit("a"), {:at_most, 2}), "aaa") == {:ok, ["a", "a"]}
    assert parse(repeat(lit("a"), {:at_least, 2}), "aaa") == {:ok, ["a", "a", "a"]}

    assert parse(repeat(lit("a")), "") == {:ok, []}
    assert parse(repeat(lit("a")), "a") == {:ok, ["a"]}
    assert parse(repeat(lit("a")), "aa") == {:ok, ["a", "a"]}
    assert parse(repeat(lit("a")), "aaa") == {:ok, ["a", "a", "a"]}
  end

  test "autoboxing" do
    assert parse(repeat("a"), "aaa") == {:ok, ["a", "a", "a"]}
    assert parse(repeat({"a"}), "aaa") == {:ok, [{"a"}, {"a"}, {"a"}]}
  end

  test "fail to parse because it fails to match an exact number of times" do
    assert parse(repeat(lit("a"), 2), "ab") == {:error,
      """
      Failed to match repeat(lit("a"), {2, 2}) at 1:1, \
      because it matched 1 times instead of 2
      """
    }
  end

  test "fail to parse because it fails to match a mininum number of times" do
    assert parse(repeat(lit("a"), {:at_least, 2}), "ab") == {:error,
      """
      Failed to match repeat(lit("a"), {2, :infinity}) at 1:1, \
      because it matched 1 times instead of at least 2 times
      """
    }
  end

  test "sugar combinators like at_least are transparent" do
    assert parse(at_least(lit("a"), 2), "ab") == {:error,
      """
      Failed to match repeat(lit("a"), {2, :infinity}) at 1:1, \
      because it matched 1 times instead of at least 2 times
      """
    }
  end
end
