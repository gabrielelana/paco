defmodule Paco.Parser.WithinEachTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse within a string" do
    assert parse(lit("a") |> within_each(lit("aaa")), "aaabbb") == {:ok, ["a"]}
  end

  test "parse within a chunk" do
    chunk = [{{0, 1, 1}, "aaa"}]
    assert parse(lit("a") |> within_each(always(chunk)), "") == {:ok, ["a"]}
  end

  test "parse withing a list of chunks" do
    parser = many(lit("a"))
    chunks = [{{0, 1, 1}, "aaa"}, {{3, 1, 4}, "aaa"}]
    expected = [["a", "a", "a"], ["a", "a", "a"]]
    assert parse(parser |> within_each(always(chunks)), "") == {:ok, expected}
  end

  test "keeps the coordinates of the inner parser" do
    parser = lit("a") |> within_each(lit("aaa"))
    success = parse(parser, "aaabbb", format: :raw)

    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
    assert success.at == {1, 1, 2}
  end

  test "keeps the tail of the outer parser" do
    parser = lit("a") |> within_each(lit("aaa"))
    success = parse(parser, "aaabbb", format: :raw)

    assert success.tail == [{{3, 1, 4}, "bbb"}]
  end

  test "doesn't apply the inner parser when outer parser fails" do
    parser = lit("a") |> within_each(lit("aaa"))
    assert parse(parser, "bbb") == {:error, ~s|expected "aaa" at 1:1 but got "bbb"|}
  end

  test "keeps the skip of the outer parser" do
    parser = lit("a") |> within_each(skip("aaa"))
    success = parse(parser, "aaa", format: :raw)

    assert success.result == ["a"]
    assert success.skip
  end

  test "skips the results of the inner parser" do
    parser = one_of([skip(lit("a")), lit("b")])

    chunks = [{{0, 1, 1}, "aaa"}, {{3, 1, 4}, "bbb"}]
    assert parse(parser |> within_each(always(chunks)), "") == {:ok, ["b"]}

    chunks = [{{0, 1, 1}, "aaa"}, {{3, 1, 4}, "aaa"}]
    assert parse(parser |> within_each(always(chunks)), "") == {:ok, []}
  end

  test "failure of the inner parser has the right position" do
    parser = [lit("aaa"), lit("a") |> within_each(lit("bbb"))]
    assert parse(parser, "aaabbb") == {:error, ~s|expected "a" at 1:4 but got "b"|}
  end

  test "fails with empty input" do
    parser = skip(lit("a")) |> within_each(lit(""))
    assert parse(parser, "") == {:error,
      ~s|expected "a" at 1:1 but got the end of input|
    }
  end
end
