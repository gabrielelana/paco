defmodule Paco.Parser.OneOf.Test do
  use ExUnit.Case

  import Paco
  import Paco.Parser

  test "parse one of the parsers" do
    assert parse(one_of([string("a"), string("b"), string("c")]), "a") == {:ok, "a"}
    assert parse(one_of([string("a"), string("b"), string("c")]), "b") == {:ok, "b"}
    assert parse(one_of([string("a"), string("b"), string("c")]), "c") == {:ok, "c"}
  end

  test "doesn't need to consume all the input" do
    assert parse(one_of([string("a"), string("b"), string("c")]), "abc") == {:ok, "a"}
  end

  test "fail to parse" do
    {:error, failure} = parse(one_of([string("a"), string("b")]), "c")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match one_of([string, string]) at line: 1, column: 1
      """
  end

  test "one parser optimization, one_of is removed" do
    assert parse(one_of([string("a")]), "a") == {:ok, "a"}

    {:error, failure} = parse(one_of([string("a")]), "c")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match string(a) at line: 1, column: 1
      """
  end
end
