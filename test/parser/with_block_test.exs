defmodule Paco.Parser.WithBlockTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse" do
    parser = lit("a") |> with_block(lit("b"))
    text = """
           a
             b
             c
             d
           e
           """
    parse(parser, text)
  end
end
