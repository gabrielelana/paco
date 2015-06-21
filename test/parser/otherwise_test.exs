defmodule Paco.Parser.OtherwiseTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse" do
    assert parse(lit("a") |> otherwise(lit("b")), "a") == {:ok, "a"}
    assert parse(lit("a") |> otherwise(lit("b")), "b") == {:ok, "b"}
  end

  test "combine failures" do
    assert parse(lit("a") |> otherwise(lit("b")), "c") == {:error,
      ~s|expected one of ["b", "a"] at 1:1 but got "c"|
    }
    assert parse(lit("aaa") |> otherwise(lit("b")), "aac") == {:error,
      ~s|expected "aaa" at 1:1 but got "aac"|
    }
  end

  test "the alternative could be a function that returns the next parser given the first" do
    alternative = fn(p) -> p |> preceded_by("b") end
    parser = lit("a") |> otherwise(alternative)

    assert parse(parser, "a") == {:ok, "a"}
    assert parse(parser, "ba") == {:ok, "a"}
  end

  test "fatal failures could not be recovered" do
    # TODO: use cut_before(lit("a")) when available
    assert parse([cut, lit("a")] |> otherwise(lit("b")), "b") == {:error,
      ~s|expected "a" at 1:1 but got "b"|
    }
  end
end
