defmodule Paco.Parser.CutTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "cut a parser success" do
    assert %Paco.Success{cut: true} = parse("a", cut(lit("a")), format: :raw)
  end

  test "cut a sewed parser success" do
    parser = cut(sew(lit("a")))
    assert %Paco.Success{cut: false, sew: false} = parse("a", parser, format: :raw)
  end

  test "doesn't cut for a parser success that didn't consume any input" do
    assert %Paco.Success{cut: false} = parse("b", cut(maybe(lit("a"))), format: :raw)
  end

  test "sew a parser success" do
    assert %Paco.Success{sew: true} = parse("a", sew(lit("a")), format: :raw)
  end

  test "sew a cutted parser success" do
    parser = sew(cut(lit("a")))
    assert %Paco.Success{cut: false, sew: false} = parse("a", parser, format: :raw)
  end

  test "doesn't sew for a parser that doesn't consume input" do
    assert %Paco.Success{sew: false} = parse("b", sew(maybe(lit("a"))), format: :raw)
  end
end
