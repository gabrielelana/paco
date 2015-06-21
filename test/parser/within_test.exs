defmodule Paco.Parser.WithinTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse within a region" do
    parser = lit("aaa") |> within(lit("a"))
    success = parse(parser, "aaabbb", format: :raw)

    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
    assert success.at == {1, 1, 2}
    assert success.result == "a"
    assert success.tail == [{{3, 1, 4}, "bbb"}]
  end

  test "doesn't apply the inner parser when outer parser is skipped" do
    parser = skip(lit("aaa")) |> within(lit("a"))
    success = parse(parser, "aaa", format: :raw)

    assert success.result == "aaa"
    assert success.skip
  end

  test "doesn't apply the inner parser when outer parser fails" do
    parser = lit("aaa") |> within(lit("a"))
    assert parse(parser, "bbb") == {:error, ~s|expected "aaa" at 1:1 but got "bbb"|}
  end

  test "keeps the skip of the inner parser" do
    parser = lit("aaa") |> within(skip(lit("a")))
    success = parse(parser, "aaa", format: :raw)

    assert success.result == "a"
    assert success.skip
  end

  test "failure of the inner parser has the right position" do
    parser = [lit("aaa"), lit("bbb") |> within(lit("a"))]
    assert parse(parser, "aaabbb") == {:error, ~s|expected "a" at 1:4 but got "b"|}
  end
end
