defmodule Paco.Parser.Seq.Test do
  use ExUnit.Case

  import Paco
  import Paco.Parser

  test "parse seq of parsers" do
    assert parse(seq([string("a"), string("b")]), "ab") == {:ok, ["a", "b"]}
    assert parse(seq([string("a")]), "a") == {:ok, ["a"]}
  end

  test "fail to parse because of the first parser" do
    {:error, failure} = parse(seq([string("a"), string("b")]), "bb")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match seq([string, string]) at line: 1, column: 1, because it
      Failed to match string(a) at line: 1, column: 1
      """
  end

  test "fail to parse because of the last parser" do
    {:error, failure} = parse(seq([string("a"), string("b")]), "aa")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match seq([string, string]) at line: 1, column: 1, because it
      Failed to match string(b) at line: 1, column: 2
      """
  end

end
