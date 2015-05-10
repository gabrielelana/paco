defmodule Paco.Parser.ReTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse" do
    assert parse(re(~r/a+/), "a") == {:ok, "a"}
    assert parse(re(~r/a+/), "aa") == {:ok, "aa"}
    assert parse(re(~r/a+/), "aaa") == {:ok, "aaa"}
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

  # captures
  # captures with names
  # wait_for in stream mode
  # wait_for could be a function
  # notify events
  # anchoring
end
