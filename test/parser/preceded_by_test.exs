defmodule Paco.Parser.PrecededByTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse something only if it's preceded by something that will be skipped" do
    assert parse(lit("a") |> preceded_by(lit("b")), "ba") == {:ok, "a"}
  end

  test "boxing: the first argument is turned into a parser" do
    assert parse("a" |> preceded_by(lit("b")), "ba") == {:ok, "a"}
  end

  test "boxing: the second argument is turned into a parser" do
    assert parse(lit("a") |> preceded_by("b"), "ba") == {:ok, "a"}
  end

  test "failure" do
    assert parse(lit("a") |> preceded_by(lit("b")), "ca") == {:error,
      ~s|expected "b" at 1:1 but got "c"|
    }
  end
end
