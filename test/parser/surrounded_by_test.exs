defmodule Paco.Parser.SurroundedByTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "success" do
    assert parse(surrounded_by(lit("a"), lit("["), lit("]")), "[a]") == {:ok, "a"}
    assert parse(surrounded_by(lit("a"), lit("*")), "*a*") == {:ok, "a"}
  end

  test "boxing: boundaries are boxes with lex instead of lit" do
    parser = surrounded_by("a", "[", "]")
    assert parse(parser, "[a]") == {:ok, "a"}
    assert parse(parser, "[ a ]") == {:ok, "a"}
    assert parse(parser, " [a] ") == {:ok, "a"}
  end

  test "describe" do
    assert describe(surrounded_by(lit("a"), lit("["), lit("]"))) ==
      ~s|surrounded_by(lit("a"), lit("["), lit("]"))|
  end

  test "describe displays things after boxing" do
    assert describe(surrounded_by("a", "[", "]")) ==
      ~s|surrounded_by(lit("a"), lex("["), lex("]"))|
  end

  test "failure because of surrounded parser" do
    assert parse(surrounded_by(lit("a"), lit("["), lit("]")), "[b]") == {:error,
      """
      Failed to match surrounded_by(lit("a"), lit("["), lit("]")) at 1:1, \
      because it failed to match lit("a") at 1:2
      """
    }
  end

  test "failure because of left parser" do
    assert parse(surrounded_by(lit("a"), lit("["), lit("]")), "*a]") == {:error,
      """
      Failed to match surrounded_by(lit("a"), lit("["), lit("]")) at 1:1, \
      because it failed to match lit("[") at 1:1
      """
    }
  end

  test "failure because of right parser" do
    assert parse(surrounded_by(lit("a"), lit("["), lit("]")), "[a*") == {:error,
      """
      Failed to match surrounded_by(lit("a"), lit("["), lit("]")) at 1:1, \
      because it failed to match lit("]") at 1:3
      """
    }
  end
end
