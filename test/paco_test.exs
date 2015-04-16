defmodule Paco.Test do
  import Paco.Parser
  use ExUnit.Case

  test "the truth" do
    assert 1 + 1 == 2
  end

  test "simple string" do
    assert parse(string("aaa"), "aaa") == {:ok, "aaa"}
  end

  test "multibyte string" do
    assert parse(string("あいうえお"), "あいうえお") == {:ok, "あいうえお"}
  end

  test "empty string" do
    assert parse(string(""), "") == {:ok, ""}
  end

  test "seq ok" do
    assert parse(seq([string("a"), string("b")]), "ab") == {:ok, ["a", "b"]}
  end

  test "one_of ok" do
    assert parse(one_of([string("a"), string("b")]), "a") == {:ok, "a"}
    assert parse(one_of([string("a"), string("b")]), "b") == {:ok, "b"}
  end

  test "seq failure" do
    {:error, failure} = parse(seq([string("a"), string("b")]), "aa")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match seq at line: 1, column: 1 <because> Failed to match string(b) at line: 1, column: 2
      """
    {:error, failure} = parse(seq([string("a"), string("\n"), string("b")]), "a\na")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match seq at line: 1, column: 1 <because> Failed to match string(b) at line: 2, column: 1
      """
  end

  test "one_of failure" do
    {:error, failure} = parse(one_of([string("a"), string("b")]), "c")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match one_of(string(a) | string(b)) at line: 1, column: 1
      """
  end
end
