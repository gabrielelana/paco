defmodule Paco.Parser.SeparatedByTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse elements separated by a delimiter" do
    parser = lit("a") |> separated_by(lex(","))

    assert parse(parser, "") == {:ok, []}
    assert parse(parser, "a") == {:ok, ["a"]}
    assert parse(parser, "a,a") == {:ok, ["a", "a"]}
    assert parse(parser, "a,a,a") == {:ok, ["a", "a", "a"]}
    assert parse(parser, "a, a, a") == {:ok, ["a", "a", "a"]}
  end

  test "takes the same options as repeat and while" do
    parser = lit("a") |> separated_by(lex(","), at_least: 1)
    assert parse(parser, "") == {:error,
      ~s|expected "a" at 1:1 but got the end of input|
    }
    assert parse(parser, "a") == {:ok, ["a"]}

    parser = lit("a") |> separated_by(lex(","), at_least: 2)
    assert parse(parser, "") == {:error,
      ~s|expected "a" at 1:1 but got the end of input|
    }
    assert parse(parser, "a") == {:error,
      ~s|expected "," at 1:2 but got the end of input|
    }
    assert parse(parser, "a,a") == {:ok, ["a", "a"]}

    parser = lit("a") |> separated_by(lex(","), at_most: 2)
    assert parse(parser, "a") == {:ok, ["a"]}
    assert parse(parser, "a,a") == {:ok, ["a", "a"]}
    assert parse(parser, "a,a,a") == {:ok, ["a", "a"]}
    assert parse(parser, "a,a,a,a") == {:ok, ["a", "a"]}
  end

  test "does not fail when it does not match the first element" do
    parser = lit("a") |> separated_by(lex(","))
    assert parse(parser, "b") == {:ok, []}

    # unless you specify that at least one element must match
    parser = lit("a") |> separated_by(lex(","), at_least: 1)
    assert parse(parser, "b") == {:error, ~s|expected "a" at 1:1 but got "b"|}
  end

  test "can keep the separator" do
    parser = lit("a") |> separated_by(keep(lex(",")))

    assert parse(parser, "a") == {:ok, ["a"]}
    assert parse(parser, "a,a") == {:ok, ["a", ",", "a"]}
    assert parse(parser, "a,a,a") == {:ok, ["a", ",", "a", ",", "a"]}
  end

  test "keeps the structure of the parsed elements" do
    parser = sequence_of([lit("a"), lit("b")])
             |> separated_by(lex(","))

    assert parse(parser, "ab,ab") == {:ok, [["a", "b"], ["a", "b"]]}

    parser = one_of([sequence_of([lit("a"), lit("b")]), lit("c")])
             |> separated_by(lex(","))

    assert parse(parser, "ab,c,ab,c") == {:ok, [["a", "b"], "c", ["a", "b"], "c"]}
  end

  test "helper to reduce the result when you keep the separator" do
    reduce = fn "+", n, m -> n + m
                "-", n, m -> n - m
             end

    parser = lit("1") |> replace_with(1)
             |> separated_by(keep(one_of([lex("+"), lex("-")])))
             |> bind(&Paco.Transform.separated_by(&1, reduce))

    assert parse(parser, "1+1") == {:ok, 2}
    assert parse(parser, "1+1+1+1") == {:ok, 4}
    assert parse(parser, "1-1") == {:ok, 0}
    assert parse(parser, "1+1-1-1") == {:ok, 0}
  end

  test "uses the cut on separator" do
    parser = lit("a") |> separated_by(lex(","))
    assert parse(parser, "a,") == {:error,
      ~s|expected "a" at 1:3 but got the end of input|
    }
  end

  test "can sew the cut" do
    parser = lit("a") |> separated_by(sew(lex(",")))
    assert parse(parser, "a,") == {:ok, ["a"]}
  end

  test "boxing: delimiter is boxes with lex instead of lit" do
    parser = separated_by("a", ",")
    assert parse(parser, "a,a") == {:ok, ["a", "a"]}
    assert parse(parser, "a , a") == {:ok, ["a", "a"]}
  end
end
