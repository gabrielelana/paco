defmodule Paco.Parser.WithBlockTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser


  test "parse without indented block" do
    parser = lit("a") |> with_block(lit("b"))
    text = """
           a
           """
    assert parse(text, parser) == {:ok, "a"}
  end

  test "parse indented block (2 spaces)" do
    block = fn gap -> lit("b") |> preceded_by(gap) end
    parser = lit("a") |> with_block(block)
    text = """
           a
             b
           """
    assert parse(text, parser) == {:ok, {"a", "b"}}
  end

  test "parse indented block (4 spaces)" do
    block = fn gap -> lit("b") |> preceded_by(gap) end
    parser = lit("a") |> with_block(block)
    text = """
           a
               b
           """
    assert parse(text, parser) == {:ok, {"a", "b"}}
  end

  test "parse indented block (1 tab)" do
    block = fn gap -> lit("b") |> preceded_by(gap) end
    parser = lit("a") |> with_block(block)
    text = """
           a
           \tb
           """
    assert parse(text, parser) == {:ok, {"a", "b"}}
  end

  test "parse indented block with few lines" do
    block = fn gap ->
              many(line(lit("b") |> preceded_by(gap)))
            end
    parser = lit("a") |> with_block(block)
    text = """
           a
             b
             b
             b
           """
    assert parse(text, parser) == {:ok, {"a", ["b", "b", "b"]}}
  end

  test "parse indented block followed by a non indented line" do
    block = fn gap ->
              many(line(lit("b") |> preceded_by(gap)))
            end
    parser = lit("a") |> with_block(block)
    text = """
           a
             b
             b
           e
           """
    assert parse(text, parser) == {:ok, {"a", ["b", "b"]}}
  end

  test "parse sequence of recursively indented blocks" do
    block = fn block ->
              fn gap ->
                many(line(lit("b") |> preceded_by(gap)))
                |> with_block(block.(block))
              end
            end
    parser = lit("a") |> with_block(block.(block))
    text = """
           a
             b
               b
                 b
           """
    assert parse(text, parser) == {:ok, {"a", {["b"], {["b"], ["b"]}}}}
  end

  test "fail to match the header" do
    parser = lit("a") |> with_block(lit("b"))
    text = """
           b
           """
    assert parse(text, parser) == {:error, ~s|expected "a" at 1:1 but got "b"|}
  end

  test "failure depends on the inner parser" do
    text = """
           a
             c
           """

    # This will not fail because the the parser (many) of the indented body
    # allows the body to be empty
    block = fn gap -> many(lit("b") |> preceded_by(gap)) end
    parser = lit("a") |> with_block(block)
    assert parse(text, parser) == {:ok, {"a", []}}

    # We could use the end of input, but the error is not very informative
    parser = lit("a") |> with_block(block) |> followed_by(eof)
    assert parse(text, parser) == {:error, ~s|expected the end of input at 2:1|}

    # The best thing to do is to use the cut asserting that after the gap you
    # must find what it is supposed to be in an indented block
    block = fn gap -> many(lit("b") |> preceded_by(cut(gap))) end
    parser = lit("a") |> with_block(block)
    assert parse(text, parser) == {:error, ~s|expected "b" at 2:3 but got "c"|}
  end
end
