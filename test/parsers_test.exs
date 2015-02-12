defmodule Paco.Parser.String.Test do
  import Paco.Parser
  use ExUnit.Case

  test "until" do
    assert parse(until(string("a")), "bbba") == {:ok, "bbb"}
    assert parse(until(string("a")), "bbb") == {:ok, "bbb"}
    assert parse(until(string("a")), "b") == {:ok, "b"}
    assert parse(until(string("a")), "") == {:ok, ""}
    assert parse(until(string("b")), "b") == {:ok, ""}
  end

  test "non" do
    assert parse(non(string("a")), "bbb") == {:ok, "b"}
    assert parse(non(string("aaa")), "aa") == {:ok, "a"}
    assert parse(non(string("a")), "") == {:error,
      # TODO: Expected not(?) at line: 1, column: 0, but got end of input
      """
      Expected not(?) at line: 1, column: 0, but got
      > |
      """
    }
    assert parse(non(string("a")), "aaa") == {:error,
      """
      Expected not(?) at line: 1, column: 0, but got
      > |aaa
      """
    }
  end

  test "between" do
    assert parse(between(string("*")), "*Hello*") == {:ok, "Hello"}
    assert parse(between(string("("), string(")")), "(1 + 2)") == {:ok, "1 + 2"}
    assert parse(between(string("("), string(")")), "(Hello\nWorld)") == {:ok, "Hello\nWorld"}
    assert parse(between(string("*")), "aaa") == {:error,
      # TODO: Expected something between string(*) at line: 1, column: 0, but got
      """
      Expected string(*) at line: 1, column: 0, but got
      > |aaa
      """
    }
  end

  test "repeat" do
    assert parse(repeat(string("a"), 0, 2), "") == {:ok, []}
    assert parse(repeat(string("a"), 1, 2), "a") == {:ok, ["a"]}
    assert parse(repeat(string("a"), 1, 2), "aa") == {:ok, ["a", "a"]}
    assert parse(repeat(string("a"), 1, 2), "aaa") == {:error,
      """
      Expected at most 2 of ? at line: 1, column: 0, but got
      > |aaa
      """
    }
    assert parse(repeat(string("a"), 1, 2), "b") == {:error,
      """
      Expected at least 1 of ? at line: 1, column: 0, but got
      > |b
      """
    }

    assert parse(repeat(string("a"), 1), "a") == {:ok, ["a"]}
    assert parse(repeat(string("a"), 2), "a") == {:error,
      """
      Expected 2 of ? at line: 1, column: 0, but got
      > |a
      """
    }
  end

  test "at_least" do
    assert parse(at_least(string("a"), 2), "aaa") == {:ok, ["a", "a", "a"]}
    assert parse(at_least(string("a"), 2), "a") == {:error,
      """
      Expected at least 2 of ? at line: 1, column: 0, but got
      > |a
      """
    }
  end

  test "at_most" do
    assert parse(at_most(string("a"), 2), "aa") == {:ok, ["a", "a"]}
    assert parse(at_most(string("a"), 2), "aaa") == {:error,
      """
      Expected at most 2 of ? at line: 1, column: 0, but got
      > |aaa
      """
    }
  end

  test "one_or_more" do
    assert parse(one_or_more(string("a")), "a") == {:ok, ["a"]}
    assert parse(one_or_more(string("a")), "aa") == {:ok, ["a", "a"]}
    assert parse(one_or_more(string("a")), "b") == {:error,
      """
      Expected at least 1 of ? at line: 1, column: 0, but got
      > |b
      """
    }
  end

  test "zero_or_more" do
    assert parse(zero_or_more(string("a")), "a") == {:ok, ["a"]}
    assert parse(zero_or_more(string("a")), "aa") == {:ok, ["a", "a"]}
    assert parse(zero_or_more(string("a")), "b") == {:ok, []}
  end

  test "match" do
    assert parse(match(~r/a+/), "aaa") == {:ok, "aaa"}
    assert parse(match(~r/a+/), "aaabbb") == {:ok, "aaa"}
    assert parse(match(~r/a(b+)a/), "abbba") == {:ok, ["bbb"]}
    assert parse(match(~r/a(b+)a/, to: fn xs -> Enum.join(xs, "") end), "abbba") == {:ok, "bbb"}
    assert parse(match(~r/a+/), "bbb") == {:error,
      """
      Expected match(~r/a+/) at line: 1, column: 0, but got
      > |bbb
      """
    }
    assert parse(match(~r/a+/), "baaa") == {:error,
      """
      Expected match(~r/a+/) at line: 1, column: 0, but got
      > |baaa
      """
    }
    assert parse(match(~r/^a+/m), "bbb\naaa") == {:error,
      """
      Expected match(~r/^a+/) at line: 1, column: 0, but got
      > |bbb\naaa
      """
    }
  end

  test "peep" do
    assert parse(seq([string("a"), peep(string("b"))]), "ab") == {:ok, ["a"]}
    assert parse(seq([string("a"), peep(string("b")), string("b")]), "ab") == {:ok, ["a", "b"]}
    assert parse(seq([string("a"), peep(string("a"))]), "ab") == {:error,
      """
      Expected string(a) at line: 1, column: 1, but got
      > a|b
      """
    }
  end

  test "always" do
    assert parse(always(:something), "aaa") == {:ok, :something}
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

    assert parse(p, "()") == {:ok, ["(", ")"]}
    assert parse(p, "[]") == {:ok, ["[", "]"]}
    assert parse(p, "[()]") == {:ok, ["[", ["(", ")"], "]"]}
    assert parse(p, "()a") == {:ok, ["(", ")"]}
    assert parse(p, "(a") == {:error,
      """
      Expected one_of(?) at line: 1, column: 0, but got
      > |(a
      """
    }
  end

  test "maybe" do
    assert parse(maybe(string("a")), "a") == {:ok, "a"}
    assert parse(maybe(string("a")), "b") == {:ok, []}
    assert parse(maybe(string("a")), "")  == {:ok, []}
  end

  test "skip" do
    assert parse(skip(string("a")), "a") == {:ok, []}

    identifier = seq([
      skip(maybe(whitespaces)),
      match(~r/[_a-zA-Z][_a-zA-Z0-9]*/),
      skip(maybe(whitespaces))
    ])

    assert parse(identifier, "a") == {:ok, ["a"]}
    assert parse(identifier, " a") == {:ok, ["a"]}
    assert parse(identifier, "a ") == {:ok, ["a"]}
    assert parse(identifier, "   a") == {:ok, ["a"]}
    assert parse(identifier, "a   ") == {:ok, ["a"]}
  end

  test "whitespaces" do
    assert parse(whitespace, " ") == {:ok, " "}
    assert parse(whitespace, "\t") == {:ok, "\t"}
    assert parse(whitespace, "\n") == {:ok, "\n"}
    assert parse(whitespaces, "   ") == {:ok, "   "}
    assert parse(whitespaces, "   a") == {:ok, "   "}
    assert parse(whitespaces, " \t  ") == {:ok, " \t  "}
    assert parse(whitespaces, " \n\t\n  ") == {:ok, " \n\t\n  "}
  end

  test "eof" do
    assert parse(eof, "") == {:ok, []}
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

  test "separated_by" do
    identifier_separated_by_comma = separated_by(match(~r/\w+/), string(","))

    assert parse(identifier_separated_by_comma, "a") == {:ok, ["a"]}
    assert parse(identifier_separated_by_comma, "a,a") == {:ok, ["a", "a"]}
    assert parse(identifier_separated_by_comma, "a,a,a") == {:ok, ["a", "a", "a"]}
  end

  test "surrounded_by" do
    identifier = surrounded_by(match(~r/\w/), skip(maybe(whitespaces)))
    identifier_quoted = surrounded_by(identifier, string(~s(")), escape_with: string("\\"))

    assert parse(identifier_quoted, ~s("a")) == {:ok, "a"}
  end

  test "nl" do
    assert parse(nl, "\n") == {:ok, "\n"}
    assert parse(nl, "\r") == {:ok, "\r"}
    assert parse(nl, "\r\n") == {:ok, "\r\n"}
    assert parse(nl, "a") == {:error,
      """
      Expected the end of line at line: 1, column: 0, but got
      > |a
      """
    }
  end

  test "line" do
    assert parse(line(string("aaa")), "aaa\n") == {:ok, "aaa"}
    assert parse(line(string("aaa")), "\naaa\n") == {:ok, "aaa"}
    assert parse(line(string("aaa")), "\n\naaa\n") == {:error,
      """
      Expected string(aaa) at line: 2, column: 0, but got
      > |
      aaa

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

  test "failed match unexpected end of input" do
    assert parse(string("aaa"), "aa") == {:error,
      """
      Expected string(aaa) at line: 1, column: 0, but got
      > |aa
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
    assert parse(string("aaa", to: &String.upcase/1), "aaa") == {:ok, "AAA"}
  end

  test "use with pipe operator" do
    assert (string("aaa") |> parse("aaa")) == {:ok, "aaa"}
  end

  test "parse s-expression" do
    lexeme = fn(p) -> p |> surrounded_by(maybe(whitespaces)) end
    number = lexeme.(match(~r/\d+/, to: &String.to_integer/1))
    expression =
      recursive(
        fn(p) ->
          one_of([number, p])
          |> separated_by(lexeme.(string(",")))
          |> surrounded_by(lexeme.(string("(")), lexeme.(string(")")))
        end
      )

    assert parse(expression, "(1, 2, 3)") == {:ok, [1, 2, 3]}
    assert parse(expression, "(1, 2, (3, 4))") == {:ok, [1, 2, [3, 4]]}
    assert parse(expression, "((1,2))") == {:ok, [[1, 2]]}
    assert parse(expression, "(2)") == {:ok, [2]}
    assert parse(expression, "((2))") == {:ok, [[2]]}
    assert parse(expression, "(1, 2)") == {:ok, [1,2]}
  end

  test "associativity" do
    expression = recursive(
      fn(e) ->
        primary = one_of([
          match(~r/\d+/, to: &String.to_integer/1) |> surrounded_by(maybe(whitespaces)),
          e |> surrounded_by(
            string("(") |> surrounded_by(maybe(whitespaces)),
            string(")") |> surrounded_by(maybe(whitespaces))
          )
        ])
        multiplicative_expression = one_of([
          primary |> separated_by(string("*"), to: fn(ns) -> Enum.reduce(ns, &Kernel.*/2) end),
          primary |> separated_by(string("/"), to: fn(ns) -> Enum.reduce(ns, &Kernel.//2) end)
          # primary |> separated_by(string("*"), to: fn [n] -> n; ns -> [:*] ++ ns end),
          # primary |> separated_by(string("/"), to: fn [n] -> n; ns -> [:/] ++ ns end)
        ])
        additive_expression = one_of([
          multiplicative_expression |> separated_by(string("+"), to: fn(ns) -> Enum.reduce(ns, &Kernel.+/2) end),
          multiplicative_expression |> separated_by(string("-"), to: fn(ns) -> Enum.reduce(ns, &Kernel.-/2) end)
          # multiplicative_expression |> separated_by(string("+"), to: fn [n] -> n; ns -> [:+] ++ ns end),
          # multiplicative_expression |> separated_by(string("-"), to: fn [n] -> n; ns -> [:-] ++ ns end)
        ])
        additive_expression
      end
    )

    assert parse(expression, "5") == {:ok, 5}
    assert parse(expression, "(5)") == {:ok, 5}
    assert parse(expression, "5 + 5") == {:ok, 10}
    assert parse(expression, "(5) + (5)") == {:ok, 10}
    assert parse(expression, "(5 + 5)") == {:ok, 10}
    assert parse(expression, "5 + 5 + 5 + 5") == {:ok, 20}
    assert parse(expression, "5 * 5") == {:ok, 25}
    assert parse(expression, "5 * 5 + 1") == {:ok, 26}
    assert parse(expression, "5 * (5 + 1)") == {:ok, 30}
    assert parse(expression, "1 + (2 * 3)") == {:ok, 7}
    assert parse(expression, "1 + 2 * 3") == {:ok, 7}
    assert parse(expression, "(1 + 2) * 3") == {:ok, 9}
  end

  test "parse docopt examples" do
    _examples =
      ~s'''
      r"""Usage: prog

      """
      $ prog
      {}

      # This is a comment

      $ prog --xxx
      "user-error"

      # This is a comment

      r"""Usage: prog [options]

      Options: -a  All.

      """
      $ prog
      {"-a": false}

      $ prog -a
      {"-a": true}

      $ prog -x
      "user-error"
      '''

    # IO.puts "\n" <> examples

    # # I would like to build a struct like
    # # %DocoptExample{usage: usage, arguments: arguments, expected: expected}

    # start = always(emit: :start)

    # # populate the usage part
    # usage = between(string(~s'r"""'), line(string(~s'""""')))
    # usage = between(string(~s'r"""'), line(string(~s'""""')), emit: :usage)

    # # populate the arguments part with
    # arguments = seq([skip(string("$ prog ")), until(nl), skip(nl)])
    # arguments = seq([skip(string("$ prog ")), until(nl), skip(nl)], emit: :usage)

    # # populate the expected part with
    # expected = until(seq([nl, one_or_more(nl)]))
    # expected = until(seq([nl, one_or_more(nl)]), emit: :expected)

    # example = seq([start, usage, many(seq[arguments, expected, skip(line(match(~r/^#.*$/)))])])

    # p =
    #   many(
    #     seq([
    #       always(%DocoptExample{}, emit: start),
    #       between(string(~s'r"""'), line(string(~s'"""')), emit: :usage),
    #       many(
    #         seq([
    #           seq([skip(string("$ prog ")), until(nl), skip(nl)], emit: :arguments),
    #           until(seq([nl, one_or_more(nl)]), emit: :expected),
    #           skip(zero_or_more(line(starts_with: "#")))
    #         ])
    #       )
    #     ])
    #   )

    # examples |> parse(p,
    #   reduce: fn
    #     (_, example, :start) -> example
    #     (usage, example, :usage) -> %DocoptExample{example | usage: usage}
    #     ([arguments], example, :arguments) -> %DocoptExample{example | arguments: arguments}
    #     (expected, example, :expected) -> %DocoptExample{example | expected: expected}
    #   end
    # )
  end

  test "parse json numbers" do
    json_number = seq([
      maybe(string("-")),
      maybe(one_of([
        string("0"),
        seq([match(~r/[1-9]/), many(match(~r/[0-9]/))])
      ])),
      maybe(string(".")),
      many(match(~r/[0-9]/)),
      maybe(seq([
        one_of([string("e"), string("E")]),
        maybe(one_of([string("+"), string("-")])),
        many(match(~r/[0-9]/))
      ])),
    ], to: fn(n) -> (n |> List.flatten |> Enum.join) end)

    assert parse(json_number, "010") == {:ok, "010"}
    assert parse(json_number, "10") == {:ok, "10"}
    assert parse(json_number, "-10") == {:ok, "-10"}
    assert parse(json_number, "-10.4") == {:ok, "-10.4"}
    assert parse(json_number, "-10.4e10") == {:ok, "-10.4e10"}
    assert parse(json_number, "-10.4e+10") == {:ok, "-10.4e+10"}
  end

  test "parse json" do
    # parser(json) do
    #   json_string = between(double_quotes)
    #   json_number = [
    #     maybe("-"),
    #     one_of([
    #       "0",
    #       [one_of(1..9), many(one_of(0..9))]
    #     ]),
    #     maybe("."),
    #     many(one_of(0..9)),
    #     maybe([
    #       one_of("e", "E"),
    #       one_of("+", "-"),
    #       one_of(0..9)
    #     ])
    #   ]
    #   parser(value) do
    #     json_object = [json_string, ":", value] |> separated_by(comma) |> surrounde_by("{", "}")
    #     json_array = value |> separated_by(comma) |> surrounded_by("[", "]"),
    #     one_of([json_string, json_number, json_object, json_array, "true", "false", "null"])
    #   end
    # end
  end

end
