defmodule Paco.Parser.CaptureTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "capture a string as region" do
    assert parse(capture(lit("a")), "a") == {:ok, [{{0, 1, 1}, "a"}]}
  end

  test "capture a string as region with a surrounding context" do
    parser = [skip(lit("b")), capture(lit("a")), skip(lit("b"))]
    assert parse(parser, "bab") == {:ok, [[{{1, 1, 2}, "a"}]]}
  end

  test "capture a sequence of parsers" do
    parser = capture([lit("a"), lit("b")])
    assert parse(parser, "ab") == {:ok, [{{0, 1, 1}, "a"},
                                         {{1, 1, 2}, "b"}]}
  end

  test "capture a sequence of parsers with some skipped" do
    parser = capture([skip(lit("a")), lit("b")])
    assert parse(parser, "ab") == {:ok, [{{1, 1, 2}, "b"}]}

    parser = capture([lit("a"), skip(lit("b"))])
    assert parse(parser, "ab") == {:ok, [{{0, 1, 1}, "a"}]}
  end

  test "capture is idempotent" do
    text = "a"
    parser = lit("a")
    assert parse(capture(parser), text) == parse(capture(capture(parser)), text)
  end

  test "release an capture" do
    text = "a"
    parser = lit("a")
    assert parse(release(capture(parser)), text) == parse(parser, text)
  end

  test "release is idempotent" do
    text = "a"
    parser = lit("a")
    assert parse(release(parser), text) == parse(release(release(parser)), text)
  end

  test "fails when result cannot be capture as a region" do
    assert parse(capture(always({})), "") == {:error,
      "cannot capture {} as a region at 1:1"
    }
  end

  test "failures remains untouched" do
    assert parse(capture(lit("a")), "b") == {:error,
      ~s|expected "a" at 1:1 but got "b"|
    }
  end
end
