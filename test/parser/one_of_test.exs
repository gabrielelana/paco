defmodule Paco.Parser.OneOf.Test do
  use ExUnit.Case

  import Paco
  import Paco.Parser

  test "parse" do
    assert parse(one_of([string("a"), string("b")]), "a") == {:ok, "a"}
    assert parse(one_of([string("a"), string("b")]), "b") == {:ok, "b"}
  end

  test "fail to parse" do
    {:error, failure} = parse(one_of([string("a"), string("b")]), "c")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match one_of(string(a) | string(b)) at line: 1, column: 1
      """
  end
end
