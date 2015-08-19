defmodule Paco.Parser.PrecededByTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse something only if it's preceded by something that will be skipped" do
    assert parse("ba", lit("a") |> preceded_by(lit("b"))) == {:ok, "a"}
  end

  test "boxing: the first argument is turned into a parser" do
    assert parse("ba", "a" |> preceded_by(lit("b"))) == {:ok, "a"}
  end

  test "boxing: the second argument is turned into a parser" do
    assert parse("ba", lit("a") |> preceded_by("b")) == {:ok, "a"}
  end

  test "failure" do
    assert parse("ca", lit("a") |> preceded_by(lit("b"))) == {:error,
      ~s|expected "b" at 1:1 but got "c"|
    }
  end
end
