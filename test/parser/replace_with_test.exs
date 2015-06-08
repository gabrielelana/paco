defmodule Paco.Parser.ReplaceWithTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "replace result with another value" do
    assert parse(lit("a") |> replace_with("b"), "a") == {:ok, "b"}
  end

  test "boxing: the first argument is turned into a parser" do
    assert parse("a" |> replace_with("b"), "a") == {:ok, "b"}
  end

  test "it has no effect on failures" do
    assert parse(lit("a") |> replace_with("b"), "b") == {:error,
      ~s|expected "a" at 1:1 but got "b"|
    }
  end
end
