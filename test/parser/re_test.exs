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

  # captures with names
  # check indexes in %Success
  # wait_for in stream mode
  # wait_for could be a function
  # notify events
  # anchoring
end
