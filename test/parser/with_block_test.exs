defmodule Paco.Parser.WithBlockTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser


  test "parse without indented block" do
    parser = lit("a") |> with_block(lit("b"))
    text = """
           a
           """
    assert parse(parser, text) == {:ok, "a"}

    text = """
           a
           a
           """
    assert parse(parser, text) == {:ok, "a"}
  end

  test "parse with indented block of one line" do
    parser = lit("a") |> with_block(many(lit("b")))
    text = """
           a
             b
           """
    assert parse(parser, text) == {:ok, {"a", ["b"]}}
  end

  test "parse with indented block of few lines" do
    parser = lit("a") |> with_block(many(lit("b")))
    text = """
           a
             b
             b
             b
           """
    assert parse(parser, text) == {:ok, {"a", ["b", "b", "b"]}}
  end

  test "parse with indented block followed by a non indented line" do
    parser = lit("a") |> with_block(many(lit("b")))
    text = """
           a
             b
             b
           e
           """
    assert parse(parser, text) == {:ok, {"a", ["b", "b"]}}
  end

  test "lines inside the indented block could be further indented" do
    parser = lit("a") |> with_block(many(lex("b")))
    text = """
           a
             b
               b
           """
    assert parse(parser, text) == {:ok, {"a", ["b", "b"]}}
  end

  test "fail to match the header" do
    parser = lit("a") |> with_block(many(lit("b")))
    text = """
           b
           """
    assert parse(parser, text) == {:error, ~s|expected "a" at 1:1 but got "b"|}
  end

  test "failure inside the block depends on the parser" do
    # expecting exacly lit("b") will fail
    parser = lit("a") |> with_block(lit("b"))
    text = """
           a
             c
           """
    assert parse(parser, text) == {:error, ~s|expected "b" at 2:3 but got "c"|}

    # expecting many lit("b") isn't going to fail unless you know
    # how many do you expect or you use the cut
    parser = lit("a") |> with_block(many(lit("b")))
    text = """
           a
             b
             c
           """
    assert parse(parser, text) == {:ok, {"a", ["b"]}}
  end

  test "coordinates" do
    parser = lit("a") |> with_block(many(lit("b")))
    text = """
           a
             b
             b
           e
           """
    result = parse(parser, text, format: :raw)

    assert result.from == {0, 1, 1}
    assert result.to == {8, 3, 3}
    assert result.at == {9, 3, 4}
  end
end
