defmodule Paco.Parser.SkipTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "skip" do
    result = parse("a", skip(lit("a")), format: :raw)
    assert result.skip
  end

  test "skip if empty" do
    result = parse("a", skip(lit("a"), if_empty: true), format: :raw)
    refute result.skip

    result = parse("", skip(lit(""), if_empty: true), format: :raw)
    assert result.skip

    result = parse("b", skip(many(lit("a")), if_empty: true), format: :raw)
    assert result.skip
  end

  test "doesn't skip a keep" do
    result = parse("a", skip(keep(lit("a"))), format: :raw)
    refute result.skip
  end

  test "doesn't skip a failure" do
    text = "b"
    parser = lit("a")
    assert parse(text, skip(parser)) == parse(text, parser)
  end
end
