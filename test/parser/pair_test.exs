defmodule Paco.Parser.PairTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "pair with separator" do
    parser = pair(lit("a"), lit("b"), separated_by: lit(":"))
    assert parse("a:b", parser) == {:ok, {"a", "b"}}
  end

  test "pair with guessed separator" do
    parser = pair(lit("a"), lit("b"))
    assert parse("a:b", parser) == {:ok, {"a", "b"}}
    assert parse("a,b", parser) == {:ok, {"a", "b"}}
    assert parse("a=b", parser) == {:ok, {"a", "b"}}
    assert parse("a/b", parser) == {:ok, {"a", "b"}}
    assert parse("a<>b", parser) == {:ok, {"a", "b"}}
    assert parse("a==b", parser) == {:ok, {"a", "b"}}
  end

  test "boxing" do
    parser = pair("a", "b", separated_by: ":")
    assert parse("a:b", parser) == {:ok, {"a", "b"}}
    assert parse("a: b", parser) == {:ok, {"a", "b"}}
    assert parse("a :b", parser) == {:ok, {"a", "b"}}
    assert parse("a : b", parser) == {:ok, {"a", "b"}}
  end

  test "fails if separator is missing" do
    parser = pair("a", "b", separated_by: ":")
    assert parse("a", parser) == {:error,
      ~s|expected ":" at 1:2 but got the end of input|
    }
  end

  test "fails if car is missing" do
    parser = pair("a", "b", separated_by: ":")
    assert parse(":b", parser) == {:error,
      ~s|expected "a" at 1:1 but got ":"|
    }
  end

  test "fails if cdr is missing" do
    parser = pair("a", "b", separated_by: ":")
    assert parse("a:", parser) == {:error,
      ~s|expected "b" at 1:3 but got the end of input|
    }
  end

  test "after separator is a fatal failure" do
    parser = one_of([pair(lit("a"), lit("b"), separated_by: lit(":")),
                     lit("a:")])

    assert parse("a:", parser) == {:error,
      ~s|expected "b" at 1:3 but got the end of input|
    }
  end
end
