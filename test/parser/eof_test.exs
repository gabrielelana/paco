defmodule Paco.Parser.EndOfInputTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse end of input" do
    assert parse("", eof) == {:ok, ""}
  end

  test "it's skipped by default" do
    assert parse("a", sequence_of([lit("a"), eof])) == {:ok, ["a"]}
  end

  test "failure" do
    assert parse("a", eof) == {:error, "expected the end of input at 1:1"}
  end
end
