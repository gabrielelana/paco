defmodule Paco.Parser.KeepTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "keep" do
    result = parse(keep(lit("a")), "a", format: :raw)
    assert result.keep
  end

  test "desn't keep a skip" do
    result = parse(keep(skip(lit("a"))), "a", format: :raw)
    refute result.keep
  end

  test "doesn't keep a failure" do
    text = "b"
    parser = lit("a")
    assert parse(keep(parser), text) == parse(parser, text)
  end
end
