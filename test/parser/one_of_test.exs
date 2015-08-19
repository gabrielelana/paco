defmodule Paco.Parser.OneOfTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse one of the parsers" do
    assert parse("a", one_of([lit("a"), lit("b"), lit("c")])) == {:ok, "a"}
    assert parse("b", one_of([lit("a"), lit("b"), lit("c")])) == {:ok, "b"}
    assert parse("c", one_of([lit("a"), lit("b"), lit("c")])) == {:ok, "c"}
    assert parse("a", one_of([lit("a")])) == {:ok, "a"}
  end

  test "boxing" do
    assert parse("a", one_of(["a", "b", "c"])) == {:ok, "a"}
    assert parse("ab", one_of([{"a", "b"}, "c"])) == {:ok, {"a", "b"}}
    assert parse("c", one_of([{"a", "b"}, "c"])) == {:ok, "c"}
  end

  test "skipped alternative returns skipped result" do
    assert %Paco.Success{skip: true} = parse("a", one_of([skip(lit("a"))]), format: :raw)
  end

  test "with no alternatives returns skipped result" do
    assert %Paco.Success{skip: true} = parse("a", one_of([]), format: :raw)
  end

  test "keep farthest failure" do
    parser = one_of([lit("ab"), lit("bc")])

    assert parse("ac", parser) == {:error,
      ~s|expected "ab" at 1:1 but got "ac"|
    }
    assert parse("ba", parser) == {:error,
      ~s|expected "bc" at 1:1 but got "ba"|
    }
  end

  test "keep deep farthest failure" do
    parser = one_of([sequence_of([lit("a"), lit("b")]),
                     sequence_of([lit("b"), lit("c")])])

    assert parse("ac", parser) == {:error,
      ~s|expected "b" at 1:2 but got "c"|
    }
    assert parse("ba", parser) == {:error,
      ~s|expected "c" at 1:2 but got "a"|
    }
  end

  test "lit goes farther than while" do
    parser = one_of([while("ab", 2), lit("ab")])

    assert parse("ac", parser) == {:error,
      ~s|expected "ab" at 1:1 but got "ac"|
    }
  end

  test "compose failures with the same rank" do
    parser = one_of([lit("aa"), lit("ab")])
    assert parse("ac", parser) == {:error,
      ~s|expected one of ["aa", "ab"] at 1:1 but got "ac"|
    }

    parser = one_of([lit("aa"), lit("ab"), lit("ad"), lit("ae")])
    assert parse("ac", parser) == {:error,
      ~s|expected one of ["aa", "ab", "ad", "ae"] at 1:1 but got "ac"|
    }
  end

  test "failure with description" do
    parser = one_of([lit("aa"), lit("bb")]) |> as("ONE_OF")

    assert parse("ac", parser) == {:error,
      ~s|expected "aa" (ONE_OF) at 1:1 but got "ac"|
    }
  end

  test "failure with nested description" do
    parser = lit("aa") |> as("LIT")
    parser = one_of([parser, lit("bb")])

    assert parse("ac", parser) == {:error,
      ~s|expected "aa" (LIT) at 1:1 but got "ac"|
    }
  end

  test "failure with stack of descriptions" do
    parser = lit("aa") |> as("LIT")
    parser = one_of([parser, lit("bb")]) |> as ("ONE_OF")

    assert parse("ac", parser) == {:error,
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
    assert parse("b", parser) == {:error, ~s|expected "a" at 1:1 but got "b"|}
  end
end
