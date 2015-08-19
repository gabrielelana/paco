defmodule Paco.Parser.OtherwiseTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse" do
    assert parse("a", lit("a") |> otherwise(lit("b"))) == {:ok, "a"}
    assert parse("b", lit("a") |> otherwise(lit("b"))) == {:ok, "b"}
  end

  test "combine failures" do
    assert parse("c", lit("a") |> otherwise(lit("b"))) == {:error,
      ~s|expected one of ["b", "a"] at 1:1 but got "c"|
    }
    assert parse("aac", lit("aaa") |> otherwise(lit("b"))) == {:error,
      ~s|expected "aaa" at 1:1 but got "aac"|
    }
  end

  test "the alternative could be a function that returns the next parser given the first" do
    alternative = fn(p) -> p |> preceded_by("b") end
    parser = lit("a") |> otherwise(alternative)

    assert parse("a", parser) == {:ok, "a"}
    assert parse("ba", parser) == {:ok, "a"}
  end

  test "fatal failures could not be recovered" do
    # TODO: use cut_before(lit("a")) when available
    assert parse("b", [cut, lit("a")] |> otherwise(lit("b"))) == {:error,
      ~s|expected "a" at 1:1 but got "b"|
    }
  end
end
