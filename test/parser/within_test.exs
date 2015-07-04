defmodule Paco.Parser.WithinTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse within a string" do
    assert parse(lit("a") |> within(lit("aaa")), "aaabbb") == {:ok, "a"}
  end

  # test "parse within a chunk" do
  #   chunk = [{{0, 1, 1}, "aaa"}]
  #   assert parse(lit("a") |> within(always(chunk)), "") == {:ok, "a"}
  # end

  # test "parse within a list of chunks" do
  #   parser = many(lit("a"))
  #   chunks = [{{0, 1, 1}, "aaa"}, {{3, 1, 4}, "aaa"}]
  #   expected = ["a", "a", "a", "a", "a", "a"]
  #   assert parse(parser |> within(always(chunks)), "") == {:ok, expected}
  # end

  test "keeps the coordinates of the inner parser" do
    parser = lit("a") |> within(lit("aa"))
    success = parse(parser, "aaabbb", format: :raw)

    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
    assert success.at == {1, 1, 2}
  end

  test "keeps the tail of the outer parser" do
    parser = lit("a") |> within(lit("aaa"))
    success = parse(parser, "aaabbb", format: :raw)

    assert success.tail == "bbb"
  end

  test "doesn't apply the inner parser when outer parser fails" do
    parser = lit("a") |> within(lit("aaa"))
    assert parse(parser, "bbb") == {:error, ~s|expected "aaa" at 1:1 but got "bbb"|}
  end

  test "keeps the skip of the outer parser" do
    parser = lit("a") |> within(skip("aaa"))
    success = parse(parser, "aaa", format: :raw)

    assert success.result == "a"
    assert success.skip
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

  test "fails with empty input" do
    parser = skip(lit("a")) |> within(lit(""))
    assert parse(parser, "") == {:error,
      ~s|expected "a" at 1:1 but got the end of input|
    }
  end
end
