defmodule Paco.Parser.SurroundedByTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse element surrounded by boundaries" do
    assert parse(surrounded_by(lit("a"), lit("["), lit("]")), "[a]") == {:ok, "a"}
    assert parse(surrounded_by(lit("a"), {lit("["), lit("]")}), "[a]") == {:ok, "a"}
    assert parse(surrounded_by(lit("a"), lit("*")), "*a*") == {:ok, "a"}
  end

  test "boxing: boundaries are boxes with lex instead of lit" do
    parser = surrounded_by("a", "[", "]")
    assert parse(parser, "[a]") == {:ok, "a"}
    assert parse(parser, "[ a ]") == {:ok, "a"}
    assert parse(parser, " [a] ") == {:ok, "a"}
  end

  test "failure because of the left boundary" do
    parser = lit("a") |> surrounded_by(lit("["), lit("]"))
    assert parse(parser, "(a]") == {:error, ~s|expected "[" at 1:1 but got "("|}
  end

  test "failure because of the right boundary" do
    parser = lit("a") |> surrounded_by(lit("["), lit("]"))
    assert parse(parser, "[a)") == {:error, ~s|expected "]" at 1:3 but got ")"|}
  end

  test "failure because of the surrounded element" do
    parser = lit("a") |> surrounded_by(lit("["), lit("]"))
    assert parse(parser, "[b]") == {:error, ~s|expected "a" at 1:2 but got "b"|}
  end

  test "failure with description" do
    parser = lit("a") |> surrounded_by(lit("["), lit("]")) |> as("SURROUNDED")
    assert parse(parser, "[b]") == {:error, ~s|expected "a" (SURROUNDED) at 1:2 but got "b"|}
  end
end
