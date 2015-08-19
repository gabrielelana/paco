defmodule Paco.Parser.KeepTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "keep" do
    result = parse("a", keep(lit("a")), format: :raw)
    assert result.keep
  end

  test "desn't keep a skip" do
    result = parse("a", keep(skip(lit("a"))), format: :raw)
    refute result.keep
  end

  test "doesn't keep a failure" do
    text = "b"
    parser = lit("a")
    assert parse(text, keep(parser)) == parse(text, parser)
  end
end
