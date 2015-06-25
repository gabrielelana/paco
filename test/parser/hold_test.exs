defmodule Paco.Parser.HoldTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "hold a string as region" do
    assert parse(hold(lit("a")), "a") == {:ok, [{{0, 1, 1}, "a"}]}
  end

  test "hold a string as region with a surrounding context" do
    parser = [skip(lit("b")), hold(lit("a")), skip(lit("b"))]
    assert parse(parser, "bab") == {:ok, [[{{1, 1, 2}, "a"}]]}
  end

  test "hold is idempotent" do
    text = "a"
    parser = lit("a")
    assert parse(hold(parser), text) == parse(hold(hold(parser)), text)
  end

  test "fails when result cannot be hold as a region" do
    assert parse(hold(always({})), "") == {:error,
      "{} cannot be hold as a region at 1:1"
    }
  end

  test "failures remains untouched" do
    assert parse(hold(lit("a")), "b") == {:error, ~s|expected "a" at 1:1 but got "b"|}
  end
end
