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
    parser = sequence_of([lit("a"), lit("b")]) |> as ("SEQUENCE")
    assert parse(parser, "bb") == {:error,
      ~s|expected "a" (SEQUENCE) at 1:1 but got "b"|
    }
    assert parse(parser, "aa") == {:error,
      ~s|expected "b" (SEQUENCE) at 1:2 but got "a"|
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

  test "failure with composed description" do
    parser = lit("a") |> as("TOKEN")
    parser = sequence_of([parser, lit("b")]) |> as("SEQUENCE")
    assert parse(parser, "bb") == {:error,
      ~s|expected "a" (TOKEN < SEQUENCE) at 1:1 but got "b"|
    }
  end

  test "report position of the failure failure" do
    parser = sequence_of([lit("a"), lit("b")])
    failure = parser.parse.(Paco.State.from("aa"), parser)
    assert failure.at == {1, 1, 2}
    assert failure.tail == "a"
  end

  test "fails in stream mode when don't consume any input" do
    # result = [""]
    #          |> Paco.Stream.parse(sequence_of([]))
    #          |> Enum.to_list
    # assert result == []

    # result = [""]
    #          |> Paco.Stream.parse(sequence_of([]), on_failure: :yield)
    #          |> Enum.to_list
    # assert result == [{:error,
    #   """
    #   Failed to match sequence_of() at 1:1, \
    #   because it didn't consume any input
    #   """
    # }]
  end
end
