defmodule Paco.Parser.SurroundedByTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse element surrounded by boundaries" do
    assert parse("[a]", surrounded_by(lit("a"), lit("["), lit("]"))) == {:ok, "a"}
    assert parse("[a]", surrounded_by(lit("a"), {lit("["), lit("]")})) == {:ok, "a"}
    assert parse("*a*", surrounded_by(lit("a"), lit("*"))) == {:ok, "a"}
  end

  test "boxing: boundaries are boxes with lex instead of lit" do
    parser = surrounded_by("a", "[", "]")
    assert parse("[a]", parser) == {:ok, "a"}
    assert parse("[ a ]", parser) == {:ok, "a"}
    assert parse(" [a] ", parser) == {:ok, "a"}
  end

  test "failure because of the left boundary" do
    parser = lit("a") |> surrounded_by(lit("["), lit("]"))
    assert parse("(a]", parser) == {:error, ~s|expected "[" at 1:1 but got "("|}
  end

  test "failure because of the right boundary" do
    parser = lit("a") |> surrounded_by(lit("["), lit("]"))
    assert parse("[a)", parser) == {:error, ~s|expected "]" at 1:3 but got ")"|}
  end

  test "failure because of the surrounded element" do
    parser = lit("a") |> surrounded_by(lit("["), lit("]"))
    assert parse("[b]", parser) == {:error, ~s|expected "a" at 1:2 but got "b"|}
  end

  test "failure with description" do
    parser = lit("a") |> surrounded_by(lit("["), lit("]")) |> as("SURROUNDED")
    assert parse("[b]", parser) == {:error, ~s|expected "a" (SURROUNDED) at 1:2 but got "b"|}
  end
end
