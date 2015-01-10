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
    assert parse(re(~r/a+/), "baaa") == {:error,
      """
      Expected re(~r/a+/) at line: 1, column: 0, but got
      > |baaa
      """
    }
    assert parse(re(~r/^a+/m), "bbb\naaa") == {:error,
      """
      Expected re(~r/^a+/) at line: 1, column: 0, but got
      > |bbb\naaa
      """
    }
  end

  test "peep" do
    assert parse(seq([string("a"), peep(string("b"))]), "ab") == {:ok, ["a", :nothing]}
    assert parse(seq([string("a"), peep(string("b")), string("b")]), "ab") == {:ok, ["a", :nothing, "b"]}
    assert parse(seq([string("a"), peep(string("a"))]), "ab") == {:error,
      """
      Expected string(a) at line: 1, column: 1, but got
      > a|b
      """
    }
  end

  test "recursive" do
    p = recursive(
      fn(p) ->
        one_of([
          seq([string("("), maybe(p), string(")")]),
          seq([string("["), maybe(p), string("]")]),
          seq([string("{"), maybe(p), string("}")])
        ])
      end
    )

    assert parse(p, "()") == {:ok, ["(", :nothing, ")"]}
    assert parse(p, "[]") == {:ok, ["[", :nothing, "]"]}
    assert parse(p, "[()]") == {:ok, ["[", ["(", :nothing, ")"], "]"]}
    assert parse(p, "()a") == {:ok, ["(", :nothing, ")"]}
    assert parse(p, "(a") == {:error,
      """
      Expected one_of(?) at line: 1, column: 0, but got
      > |(a
      """
    }
  end

  test "maybe" do
    assert parse(maybe(string("a")), "a") == {:ok, "a"}
    assert parse(maybe(string("a")), "b") == {:ok, :nothing}
    assert parse(maybe(string("a")), "")  == {:ok, :nothing}
  end

  test "whitespaces" do
    assert parse(whitespace, " ") == {:ok, " "}
    assert parse(whitespace, "\t") == {:ok, "\t"}
    assert parse(whitespace, "\n") == {:ok, "\n"}
    assert parse(whitespaces, "   ") == {:ok, "   "}
    assert parse(whitespaces, " \t  ") == {:ok, " \t  "}
    assert parse(whitespaces, " \n\t\n  ") == {:ok, " \n\t\n  "}
  end

  test "eof" do
    assert parse(eof, "") == {:ok, ""}
    assert parse(eof, "a") == {:error,
      """
      Expected the end of input at line: 1, column: 0, but got
      > |a
      """
    }
  end

  test "one_of" do
    assert parse(one_of([string("a"), string("b")]), "a") == {:ok, "a"}
    assert parse(one_of([string("a"), string("b")]), "b") == {:ok, "b"}
    assert parse(one_of([string("a"), string("b")]), "c") == {:error,
      """
      Expected one_of(?) at line: 1, column: 0, but got
      > |c
      """
    }
  end

  test "many" do
    assert parse(many(string("a")), "") == {:ok, []}
    assert parse(many(string("a")), "a") == {:ok, ["a"]}
    assert parse(many(string("a")), "aa") == {:ok, ["a", "a"]}
    assert parse(many(string("a")), "aaaaa") == {:ok, ["a", "a", "a", "a", "a"]}
    assert parse(many(string("a")), "b") == {:ok, []}
    assert parse(seq([many(string("a")), string("b")]), "b") == {:ok, [[], "b"]}
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
