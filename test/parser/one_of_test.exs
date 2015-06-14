defmodule Paco.Parser.OneOfTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse one of the parsers" do
    assert parse(one_of([lit("a"), lit("b"), lit("c")]), "a") == {:ok, "a"}
    assert parse(one_of([lit("a"), lit("b"), lit("c")]), "b") == {:ok, "b"}
    assert parse(one_of([lit("a"), lit("b"), lit("c")]), "c") == {:ok, "c"}
    assert parse(one_of([lit("a")]), "a") == {:ok, "a"}
    assert parse(one_of([]), "a") == {:ok, ""}
  end

  test "boxing" do
    assert parse(one_of(["a", "b", "c"]), "a") == {:ok, "a"}
    assert parse(one_of([{"a", "b"}, "c"]), "ab") == {:ok, {"a", "b"}}
    assert parse(one_of([{"a", "b"}, "c"]), "c") == {:ok, "c"}
  end

  test "skipped parsers should be removed from result" do
    assert parse(one_of([lit("a"), skip(lit("b"))]), "a") == {:ok, "a"}
    assert parse(one_of([lit("a"), skip(lit("b"))]), "b") == {:ok, []}
  end

  test "keep farthest failure" do
    parser = one_of([lit("ab"), lit("bc")])

    assert parse(parser, "ac") == {:error,
      ~s|expected "ab" at 1:1 but got "ac"|
    }
    assert parse(parser, "ba") == {:error,
      ~s|expected "bc" at 1:1 but got "ba"|
    }
  end

  test "keep deep farthest failure" do
    parser = one_of([sequence_of([lit("a"), lit("b")]),
                     sequence_of([lit("b"), lit("c")])])

    assert parse(parser, "ac") == {:error,
      ~s|expected "b" at 1:2 but got "c"|
    }
    assert parse(parser, "ba") == {:error,
      ~s|expected "c" at 1:2 but got "a"|
    }
  end

  test "lit goes farther than while" do
    parser = one_of([while("ab", 2), lit("ab")])

    assert parse(parser, "ac") == {:error,
      ~s|expected "ab" at 1:1 but got "ac"|
    }
  end

  test "compose failures with the same rank" do
    parser = one_of([lit("aa"), lit("ab")])
    assert parse(parser, "ac") == {:error,
      ~s|expected one of ["aa", "ab"] at 1:1 but got "ac"|
    }

    parser = one_of([lit("aa"), lit("ab"), lit("ad"), lit("ae")])
    assert parse(parser, "ac") == {:error,
      ~s|expected one of ["aa", "ab", "ad", "ae"] at 1:1 but got "ac"|
    }
  end

  test "failure with description" do
    parser = one_of([lit("aa"), lit("bb")]) |> as("ONE_OF")

    assert parse(parser, "ac") == {:error,
      ~s|expected "aa" (ONE_OF) at 1:1 but got "ac"|
    }
  end

  test "failure with nested description" do
    parser = lit("aa") |> as("LIT")
    parser = one_of([parser, lit("bb")])

    assert parse(parser, "ac") == {:error,
      ~s|expected "aa" (LIT) at 1:1 but got "ac"|
    }
  end

  test "failure with stack of descriptions" do
    parser = lit("aa") |> as("LIT")
    parser = one_of([parser, lit("bb")]) |> as ("ONE_OF")

    assert parse(parser, "ac") == {:error,
      ~s|expected "aa" (LIT < ONE_OF) at 1:1 but got "ac"|
    }
  end

  test "report position of the farthest failure" do
    parser = one_of([sequence_of([lit("a"), lit("b")]),
                     sequence_of([lit("b"), lit("c")])])
    failure = parser.parse.(Paco.State.from("ac"), parser)
    assert failure.at == {1, 1, 2}
    assert failure.tail == "c"
  end

  test "doesn't backtrack with fatal failures" do
    parser = one_of([sequence_of([cut, lit("a")]), lit("b")])
    assert parse(parser, "b") == {:error, ~s|expected "a" at 1:1 but got "b"|}
  end
end
