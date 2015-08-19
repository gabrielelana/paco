defmodule Paco.Parser.FollowedByTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse something only if it's followed by something that will be skipped" do
    assert parse("ab", lit("a") |> followed_by(lit("b"))) == {:ok, "a"}
  end

  test "boxing: the first argument is turned into a parser" do
    assert parse("ab", "a" |> followed_by(lit("b"))) == {:ok, "a"}
  end

  test "boxing: the second argument is turned into a parser" do
    assert parse("ab", lit("a") |> followed_by("b")) == {:ok, "a"}
  end

  test "failure" do
    assert parse("ac", lit("a") |> followed_by(lit("b"))) == {:error,
      ~s|expected "b" at 1:2 but got "c"|
    }
  end
end
