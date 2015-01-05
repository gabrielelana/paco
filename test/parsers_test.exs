defmodule Paco.Parser.String.Test do
  import Paco.Parser
  use ExUnit.Case

  test "perfect match" do
    assert parse(string("aaa"), "aaa") == "aaa"
    assert parse(string("あいうえお"), "あいうえお") == "あいうえお"
  end

  test "match with something left" do
    assert parse(string("aaa"), "aaa bbb") == "aaa"
  end

  test "failed match at line 1" do
    assert parse(string("aaa"), "bbb") ==
      """
      Expected string(aaa) at line: 1, column: 0, but got
      > |bbb
      """
  end

  test "failed match at line 2" do
    assert parse(seq([string("aaa\n"), string("aaa")]), "aaa\nbbb") ==
      """
      Expected string(aaa) at line: 2, column: 0, but got
      > |bbb
      """
  end

  test "failed match at column 1" do
    assert parse(seq([string("a"), string("b")]), "aaa") ==
      """
      Expected string(b) at line: 1, column: 1, but got
      > a|aa
      """
  end

  test "seq" do
    assert parse(seq([string("aaa"), string("bbb")]), "aaabbb") == ["aaa", "bbb"]
  end

  test "result could be mapped" do
    assert parse(string("aaa", map: &String.upcase/1), "aaa") == "AAA"
  end

  test "use with pipe operator" do
    assert (string("aaa") |> parse("aaa")) == "aaa"
  end

end
