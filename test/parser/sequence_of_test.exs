defmodule Paco.Parser.SequenceOfTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse sequence of parsers" do
    assert parse(sequence_of([lit("a"), lit("b")]), "ab") == {:ok, ["a", "b"]}
    assert parse(sequence_of([lit("a")]), "a") == {:ok, ["a"]}
    assert parse(sequence_of([]), "a") == {:ok, []}
  end

  test "boxing" do
    assert parse(sequence_of(["a", "b"]), "ab") == {:ok, ["a", "b"]}
  end

  test "skipped parsers should be removed from result" do
    assert parse(sequence_of([lit("a"), skip(lit("b")), lit("c")]), "abc") == {:ok, ["a", "c"]}
    assert parse(sequence_of([skip(lit("a"))]), "a") == {:ok, []}
  end

  test "fail to parse because of the first parser" do
    assert parse(sequence_of([lit("a"), lit("b")]), "bb") == {:error,
      ~s|expected "a" at 1:1 but got "b"|
    }
  end

  test "fail to parse because of the last parser" do
    assert parse(sequence_of([lit("a"), lit("b")]), "aa") == {:error,
      ~s|expected "b" at 1:2 but got "a"|
    }
  end

  test "fail to parse for end of input" do
    assert parse(sequence_of([lit("a"), lit("b")]), "a") == {:error,
      ~s|expected "b" at 1:2 but got the end of input|
    }
  end

  test "failure with description" do
    parser = sequence_of([lit("a"), lit("b")]) |> as ("SEQUENCE_OF")
    assert parse(parser, "bb") == {:error,
      ~s|expected "a" (SEQUENCE_OF) at 1:1 but got "b"|
    }
    assert parse(parser, "aa") == {:error,
      ~s|expected "b" (SEQUENCE_OF) at 1:2 but got "a"|
    }
  end

  test "failure with nested description" do
    parser = lit("a") |> as("TOKEN")
    assert parse(sequence_of([parser, lit("b")]), "bb") == {:error,
      ~s|expected "a" (TOKEN) at 1:1 but got "b"|
    }
    assert parse(sequence_of([parser, lit("b")]), "aa") == {:error,
      ~s|expected "b" at 1:2 but got "a"|
    }
  end

  test "failure with stack of descriptions" do
    parser = lit("a") |> as("TOKEN")
    parser = sequence_of([parser, lit("b")]) |> as("SEQUENCE_OF")
    assert parse(parser, "bb") == {:error,
      ~s|expected "a" (TOKEN < SEQUENCE_OF) at 1:1 but got "b"|
    }
  end

  test "report position of the farthest failure" do
    parser = sequence_of([lit("a"), lit("b")])
    failure = parser.parse.(Paco.State.from("aa"), parser)
    assert failure.at == {1, 1, 2}
    assert failure.tail == "a"
  end

  test "fails in stream mode when don't consume any input" do
    result = [""]
             |> Paco.Stream.parse(sequence_of([]))
             |> Enum.to_list
    assert result == []

    result = [""]
             |> Paco.Stream.parse(sequence_of([]), on_failure: :yield)
             |> Enum.to_list
    assert result == [{:error, ~s|failure! parser didn't consume any input|}]
  end

  test "propagate cut in the sequence" do
    parser = sequence_of([lit("a"), cut, lit("b")])

    assert %Paco.Failure{fatal: false} = parse(parser, "bb", format: :raw)
    assert %Paco.Failure{fatal: true} = parse(parser, "aa", format: :raw)
  end

  test "reset cut at the end of the sequence" do
    with_cut = sequence_of([cut, lit("a")])
    without_cut = sequence_of([lit("b")])
    parser = sequence_of([with_cut, without_cut])

    assert %Paco.Failure{fatal: true} = parse(parser, "bb", format: :raw)
    assert %Paco.Failure{fatal: false} = parse(parser, "aa", format: :raw)
    assert %Paco.Success{cut: false} = parse(parser, "ab", format: :raw)
  end

  test "inherit cut in nested sequences" do
    with_inherited_cut = sequence_of([lit("b")])
    parser = sequence_of([lit("a"), cut, with_inherited_cut])

    assert %Paco.Failure{fatal: false} = parse(parser, "bb", format: :raw)
    assert %Paco.Failure{fatal: true} = parse(parser, "aa", format: :raw)
  end

  test "sew the cut" do
    parser = sequence_of([lit("a"), cut, lit("b"), sew, lit("c")])

    assert %Paco.Failure{fatal: false} = parse(parser, "b", format: :raw)
    assert %Paco.Failure{fatal: true} = parse(parser, "aa", format: :raw)
    assert %Paco.Failure{fatal: false} = parse(parser, "ab", format: :raw)
  end
end
