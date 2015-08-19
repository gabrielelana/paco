defmodule Paco.Parser.RecursiveTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "declare a parser recursively without using a module" do
    parser = recursive(fn(p) ->
                         one_of([lit("a"), p |> surrounded_by("(", ")")])
                       end)

    assert parse("a", parser) == {:ok, "a"}
    assert parse("(a)", parser) == {:ok, "a"}
    assert parse("((a))", parser) == {:ok, "a"}
    assert parse("(((a)))", parser) == {:ok, "a"}
  end

  test "failure" do
    parser = recursive(fn(p) ->
                         one_of([lit("a"), p |> surrounded_by("(", ")")])
                       end)

    assert parse("(a", parser) == {:error,
      ~s|expected ")" at 1:3 but got the end of input|
    }
  end
end
