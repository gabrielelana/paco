defmodule Paco.Parser.PairTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "pair with separator" do
    parser = pair(lit("a"), lit("b"), separated_by: lit(":"))
    assert parse(parser, "a:b") == {:ok, {"a", "b"}}
  end

  test "pair with guessed separator" do
    parser = pair(lit("a"), lit("b"))
    assert parse(parser, "a:b") == {:ok, {"a", "b"}}
    assert parse(parser, "a,b") == {:ok, {"a", "b"}}
    assert parse(parser, "a=b") == {:ok, {"a", "b"}}
    assert parse(parser, "a/b") == {:ok, {"a", "b"}}
    assert parse(parser, "a<>b") == {:ok, {"a", "b"}}
    assert parse(parser, "a==b") == {:ok, {"a", "b"}}
  end

  test "boxing" do
    parser = pair("a", "b", separated_by: ":")
    assert parse(parser, "a:b") == {:ok, {"a", "b"}}
    assert parse(parser, "a: b") == {:ok, {"a", "b"}}
    assert parse(parser, "a :b") == {:ok, {"a", "b"}}
    assert parse(parser, "a : b") == {:ok, {"a", "b"}}
  end

  test "fails if separator is missing" do
    parser = pair("a", "b", separated_by: ":")
    assert parse(parser, "a") == {:error,
      ~s|expected ":" at 1:2 but got the end of input|
    }
  end

  test "fails if car is missing" do
    parser = pair("a", "b", separated_by: ":")
    assert parse(parser, ":b") == {:error,
      ~s|expected "a" at 1:1 but got ":"|
    }
  end

  test "fails if cdr is missing" do
    parser = pair("a", "b", separated_by: ":")
    assert parse(parser, "a:") == {:error,
      ~s|expected "b" at 1:3 but got the end of input|
    }
  end

  test "after separator is a fatal failure" do
    parser = one_of([pair(lit("a"), lit("b"), separated_by: lit(":")),
                     lit("a:")])

    assert parse(parser, "a:") == {:error,
      ~s|expected "b" at 1:3 but got the end of input|
    }
  end
end
