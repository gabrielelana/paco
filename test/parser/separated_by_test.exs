defmodule Paco.Parser.SeparatedByTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse elements separated by a delimiter" do
    parser = lit("a") |> separated_by(lex(","))

    assert parse(parser, "a") == {:ok, ["a"]}
    assert parse(parser, "a,a") == {:ok, ["a", "a"]}
    assert parse(parser, "a,a,a") == {:ok, ["a", "a", "a"]}
    assert parse(parser, "a, a, a") == {:ok, ["a", "a", "a"]}
  end

  test "takes same options as repeat/while" do
    parser = lit("a") |> separated_by(lex(","), at_least: 1)
    assert parse(parser, "a") == {:error,
      ~s|expected "," at 1:2 but got the end of input|
    }

    parser = lit("a") |> separated_by(lex(","), at_most: 2)
    assert parse(parser, "a") == {:ok, ["a"]}
    assert parse(parser, "a,a") == {:ok, ["a", "a"]}
    assert parse(parser, "a,a,a") == {:ok, ["a", "a", "a"]}
    assert parse(parser, "a,a,a,a") == {:ok, ["a", "a", "a"]}
  end

  test "keep the separator" do
    parser = lit("a") |> separated_by(keep(lex(",")))

    assert parse(parser, "a") == {:ok, ["a"]}
    assert parse(parser, "a,a") == {:ok, ["a", ",", "a"]}
    assert parse(parser, "a,a,a") == {:ok, ["a", ",", "a", ",", "a"]}
  end

  test "keep the structure of the parsed elements" do
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

  test "boxing: delimiter is boxes with lex instead of lit" do
    parser = separated_by("a", ",")
    assert parse(parser, "a,a") == {:ok, ["a", "a"]}
    assert parse(parser, "a , a") == {:ok, ["a", "a"]}
  end

  test "fails on end of input" do
    parser = lit("a") |> separated_by(lex(","))
    assert parse(parser, "") == {:error,
      ~s|expected "a" at 1:1 but got the end of input|
    }
  end

  test "fails when doesn't match the first element" do
    parser = lit("a") |> separated_by(lex(","))
    assert parse(parser, "b") == {:error, ~s|expected "a" at 1:1 but got "b"|}
  end
end
