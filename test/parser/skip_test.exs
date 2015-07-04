defmodule Paco.Parser.SkipTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "skip" do
    result = parse(skip(lit("a")), "a", format: :raw)
    assert result.skip
  end

  test "skip if empty" do
    result = parse(skip(lit("a"), if_empty: true), "a", format: :raw)
    refute result.skip

    result = parse(skip(lit(""), if_empty: true), "", format: :raw)
    assert result.skip

    # result = parse(skip(many(lit("a")), if_empty: true), "b", format: :raw)
    # assert result.skip
  end

  test "doesn't skip a keep" do
    result = parse(skip(keep(lit("a"))), "a", format: :raw)
    refute result.skip
  end

  test "doesn't skip a failure" do
    text = "b"
    parser = lit("a")
    assert parse(skip(parser), text) == parse(parser, text)
  end
end
