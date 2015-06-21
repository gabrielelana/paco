defmodule Paco.Parser.WithinTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse within a string" do
    assert parse(lit("a") |> within(lit("aaa")), "aaabbb") == {:ok, "a"}
  end

  test "parse within a string keeps the position" do
    parser = lit("a") |> within(lit("aaa"))
    success = parse(parser, "aaabbb", format: :raw)

    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
    assert success.at == {1, 1, 2}
  end

  test "parse within a chunk" do
    chunk = [{{0, 1, 1}, "aaa"}]
    assert parse(lit("a") |> within(always(chunk)), "aaabbb") == {:ok, "a"}
  end

  test "parse within a chunk keeps the position" do
    chunk = [{{4, 2, 5}, "aaa"}]
    success = parse(lit("a") |> within(always(chunk)), "", format: :raw)

    assert success.from == {4, 2, 5}
    assert success.to == {4, 2, 5}
    assert success.at == {5, 2, 6}
  end


  test "keeps the tail of the outer parser" do
    parser = lit("a") |> within(lit("aaa"))
    success = parse(parser, "aaabbb", format: :raw)

    assert success.tail == [{{3, 1, 4}, "bbb"}]
  end

  test "doesn't apply the inner parser when outer parser is skipped" do
    parser = lit("a") |> within(skip("aaa"))
    success = parse(parser, "aaa", format: :raw)

    assert success.result == "aaa"
    assert success.skip
  end

  test "doesn't apply the inner parser when outer parser fails" do
    parser = lit("a") |> within(lit("aaa"))
    assert parse(parser, "bbb") == {:error, ~s|expected "aaa" at 1:1 but got "bbb"|}
  end

  test "keeps the skip of the inner parser" do
    parser = skip(lit("a")) |> within(lit("aaa"))
    success = parse(parser, "aaa", format: :raw)

    assert success.result == "a"
    assert success.skip
  end

  test "failure of the inner parser has the right position" do
    parser = [lit("aaa"), lit("a") |> within(lit("bbb"))]
    assert parse(parser, "aaabbb") == {:error, ~s|expected "a" at 1:4 but got "b"|}
  end
end
