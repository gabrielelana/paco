defmodule Paco.Parser.Seq.Test do
  use ExUnit.Case

  import Paco
  import Paco.Parser

  test "parse seq of parsers" do
    assert parse(seq([string("a"), string("b")]), "ab") == {:ok, ["a", "b"]}
    assert parse(seq([string("a")]), "a") == {:ok, ["a"]}
  end

  test "with no parsers" do
    assert_raise ArgumentError, fn -> seq([]) end
  end

  test "fail to parse because of the first parser" do
    {:error, failure} = parse(seq([string("a"), string("b")]), "bb")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match seq([string(a), string(b)]) at 1:1, because it failed to match string(a) at 1:1
      """
  end

  test "fail to parse because of the last parser" do
    {:error, failure} = parse(seq([string("a"), string("b")]), "aa")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match seq([string(a), string(b)]) at 1:1, because it failed to match string(b) at 1:2
      """
  end
end
