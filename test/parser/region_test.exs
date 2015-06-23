defmodule Paco.Parser.RegionTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "creates a region out of a string result" do
    parser = lit("a")
    assert parse(parser, "a") == {:ok, "a"}
    assert parse(region(parser), "a") == {:ok, [{{0, 1, 1}, "a"}]}
  end

  test "extract a region out of context" do
    parser = [skip(lit("b")), lit("a") |> region, skip(lit("b"))]
    assert parse(parser, "bab") == {:ok, [[{{1, 1, 2}, "a"}]]}
  end

  test "is idempotent" do
    text = "a"
    parser = lit("a")
    assert parse(region(parser), text) == parse(region(region(parser)), text)
  end

  test "fails when result cannot be turned into a region" do
    assert parse(region(always({})), "") == {:error,
      "{} cannot be turned into a region at 1:1"
    }
  end

  test "failures remains untouched" do
    assert parse(region(lit("a")), "b") == {:error, ~s|expected "a" at 1:1 but got "b"|}
  end
end
