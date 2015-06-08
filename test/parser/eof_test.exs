defmodule Paco.Parser.EndOfInputTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse end of input" do
    # Avoid to use parse(eof, "") because eof is skipped by default
    # and the behaviour of parsing with a top level parser skipped it's
    # still unclear
    parser = eof
    success = parser.parse.(Paco.State.from(""), parser)
    assert success.result == ""
  end

  test "it's skipped by default" do
    # To get a clean result use followed_by in this case
    assert parse(sequence_of([lit("a"), eof]), "a") == {:ok, ["a"]}
  end

  test "failure" do
    assert parse(eof, "a") == {:error, "expected the end of input at 1:1"}
  end
end
