defmodule Paco.Parser.ReplaceWithTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "replace result with another value" do
    assert parse("a", lit("a") |> replace_with("b")) == {:ok, "b"}
  end

  test "boxing: the first argument is turned into a parser" do
    assert parse("a", "a" |> replace_with("b")) == {:ok, "b"}
  end

  test "it has no effect on failures" do
    assert parse("b", lit("a") |> replace_with("b")) == parse("b", lit("a"))
  end
end
