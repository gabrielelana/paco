defmodule Paco.Parser.FollowedByTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse something only if it's followed by something that will be skipped" do
    assert parse(lit("a") |> followed_by(lit("a")), "aa") == {:ok, "a"}
  end

  test "boxing: the first argument is turned into a parser" do
    assert parse("a" |> followed_by(lit("a")), "aa") == {:ok, "a"}
  end

  test "boxing: the second argument is turned into a parser" do
    assert parse(lit("a") |> followed_by("a"), "aa") == {:ok, "a"}
  end

  test "failure" do
    assert parse(lit("a") |> followed_by(lit("a")), "ac") == {:error,
      ~s|expected "a" at 1:2 but got "c"|
    }
  end
end
