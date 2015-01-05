defmodule Paco.Parser.String.Test do
  import Paco.Parser
  use ExUnit.Case

  test "re" do
    assert parse(re(~r/a+/), "aaa") == {:ok, "aaa"}
    assert parse(re(~r/a+/), "aaabbb") == {:ok, "aaa"}
    assert parse(re(~r/a(b+)a/), "abbba") == {:ok, ["bbb"]}
    assert parse(re(~r/a(b+)a/, map: fn xs -> Enum.join(xs, "") end), "abbba") == {:ok, "bbb"}
    assert parse(re(~r/a+/), "bbb") == {:error,
      """
      Expected re(~r/a+/) at line: 1, column: 0, but got
      > |bbb
      """
    }
  end

  test "perfect match" do
    assert parse(string("aaa"), "aaa") == {:ok, "aaa"}
    assert parse(string("あいうえお"), "あいうえお") == {:ok, "あいうえお"}
  end

  test "perfect match!" do
    assert parse!(string("aaa"), "aaa") == "aaa"
    assert parse!(string("あいうえお"), "あいうえお") == "あいうえお"
  end

  test "match with something left" do
    assert parse(string("aaa"), "aaa bbb") == {:ok, "aaa"}
  end

  test "failure!" do
    assert_raise Paco.Parser.Error, fn ->
      parse!(string("aaa"), "bbb")
    end
  end

  test "failed match at line 1" do
    assert parse(string("aaa"), "bbb") == {:error,
      """
      Expected string(aaa) at line: 1, column: 0, but got
      > |bbb
      """
    }
  end

  test "failed match at line 2" do
    assert parse(seq([string("aaa\n"), string("aaa")]), "aaa\nbbb") == {:error,
      """
      Expected string(aaa) at line: 2, column: 0, but got
      > |bbb
      """
    }
  end

  test "failed match at column 1" do
    assert parse(seq([string("a"), string("b")]), "aaa") == {:error,
      """
      Expected string(b) at line: 1, column: 1, but got
      > a|aa
      """
    }
  end

  test "seq" do
    assert parse(seq([string("aaa"), string("bbb")]), "aaabbb") == {:ok, ["aaa", "bbb"]}
  end

  test "result could be mapped" do
    assert parse(string("aaa", map: &String.upcase/1), "aaa") == {:ok, "AAA"}
  end

  test "use with pipe operator" do
    assert (string("aaa") |> parse("aaa")) == {:ok, "aaa"}
  end

end
