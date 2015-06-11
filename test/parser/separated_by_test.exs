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

  test "TODO: uses cut on separator" do
    parser = lit("a") |> separated_by(lex(","))

    # that's a good case for using the cut combinator when you find "," then
    # the following element is mandatory, for now this is the best we can do,
    # but this assertion must fail with a meaningful message
    assert parse(parser, "a,b") == {:ok, ["a"]}
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
