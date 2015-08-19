defmodule Paco.Parser.SequenceOfTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse sequence of parsers" do
    assert parse("ab", sequence_of([lit("a"), lit("b")])) == {:ok, ["a", "b"]}
    assert parse("a", sequence_of([lit("a")])) == {:ok, ["a"]}
    assert parse("a", sequence_of([])) == {:ok, []}
  end

  test "boxing" do
    assert parse("ab", sequence_of(["a", "b"])) == {:ok, ["a", "b"]}
  end

  test "skipped parsers should be removed from result" do
    assert parse("abc", sequence_of([lit("a"), skip(lit("b")), lit("c")])) == {:ok, ["a", "c"]}
    assert parse("a", sequence_of([skip(lit("a"))])) == {:ok, []}
  end

  test "fail to parse because of the first parser" do
    assert parse("bb", sequence_of([lit("a"), lit("b")])) == {:error,
      ~s|expected "a" at 1:1 but got "b"|
    }
  end

  test "fail to parse because of the last parser" do
    assert parse("aa", sequence_of([lit("a"), lit("b")])) == {:error,
      ~s|expected "b" at 1:2 but got "a"|
    }
  end

  test "fail to parse for end of input" do
    assert parse("a", sequence_of([lit("a"), lit("b")])) == {:error,
      ~s|expected "b" at 1:2 but got the end of input|
    }
  end

  test "failure with description" do
    parser = sequence_of([lit("a"), lit("b")]) |> as ("SEQUENCE_OF")
    assert parse("bb", parser) == {:error,
      ~s|expected "a" (SEQUENCE_OF) at 1:1 but got "b"|
    }
    assert parse("aa", parser) == {:error,
      ~s|expected "b" (SEQUENCE_OF) at 1:2 but got "a"|
    }
  end

  test "failure with nested description" do
    parser = lit("a") |> as("TOKEN")
    assert parse("bb", sequence_of([parser, lit("b")])) == {:error,
      ~s|expected "a" (TOKEN) at 1:1 but got "b"|
    }
    assert parse("aa", sequence_of([parser, lit("b")])) == {:error,
      ~s|expected "b" at 1:2 but got "a"|
    }
  end

  test "failure with stack of descriptions" do
    parser = lit("a") |> as("TOKEN")
    parser = sequence_of([parser, lit("b")]) |> as("SEQUENCE_OF")
    assert parse("bb", parser) == {:error,
      ~s|expected "a" (TOKEN < SEQUENCE_OF) at 1:1 but got "b"|
    }
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

  test "cut in the sequence" do
    parser = sequence_of([lit("a"), cut, lit("b")])
    assert %Paco.Failure{fatal: false} = parse("b", parser, format: :raw)
    assert %Paco.Failure{fatal: true} = parse("aa", parser, format: :raw)

    parser = sequence_of([cut(lit("a")), lit("b")])
    assert %Paco.Failure{fatal: false} = parse("b", parser, format: :raw)
    assert %Paco.Failure{fatal: true} = parse("aa", parser, format: :raw)
  end

  test "cut and sew are skipped" do
    parser = sequence_of([lit("a"), cut, lit("b"), sew, lit("c")])
    assert parse("abc", parser) == {:ok, ["a", "b", "c"]}
  end

  test "sew the cut in the sequence" do
    parser = sequence_of([lit("a"), cut, lit("b"), sew, lit("c")])
    assert %Paco.Failure{fatal: false} = parse("b", parser, format: :raw)
    assert %Paco.Failure{fatal: true} = parse("aa", parser, format: :raw)
    assert %Paco.Failure{fatal: false} = parse("ab", parser, format: :raw)

    parser = sequence_of([cut(lit("a")), sew(lit("b")), lit("c")])
    assert %Paco.Failure{fatal: false} = parse("b", parser, format: :raw)
    assert %Paco.Failure{fatal: true} = parse("aa", parser, format: :raw)
    assert %Paco.Failure{fatal: false} = parse("ab", parser, format: :raw)
  end

  test "cut the sew in the sequence" do
    parser = sequence_of([sew, lit("a"), cut, lit("b")])
    assert %Paco.Failure{fatal: false} = parse("b", parser, format: :raw)
    assert %Paco.Failure{fatal: false} = parse("aa", parser, format: :raw)

    parser = sequence_of([sew(lit("a")), cut(lit("b"))])
    assert %Paco.Failure{fatal: false} = parse("b", parser, format: :raw)
    assert %Paco.Failure{fatal: false} = parse("aa", parser, format: :raw)
  end

  test "consumes input on success" do
    parser = sequence_of([lit("a"), lit("b")])
    success = parser.parse.(Paco.State.from("abc"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {1, 1, 2}
    assert success.at == {2, 1, 3}
    assert success.tail == "c"
  end

  test "does not consume input on failure" do
    parser = sequence_of([lit("a"), lit("b")])
    failure = parser.parse.(Paco.State.from("bbb"), parser)
    assert failure.at == {0, 1, 1}
    assert failure.tail == "bbb"
  end

  test "report position of the farthest failure" do
    parser = sequence_of([lit("a"), lit("b")])
    failure = parser.parse.(Paco.State.from("aa"), parser)
    assert failure.at == {1, 1, 2}
    assert failure.tail == "a"
  end

  test "does not include head skips in success coordinates" do
    parser = sequence_of([skip(lit("a")), lit("b")])
    success = parser.parse.(Paco.State.from("abc"), parser)
    assert success.from == {1, 1, 2}
    assert success.to == {1, 1, 2}
  end

  test "does not include tail skips in success coordinates" do
    parser = sequence_of([lit("a"), skip(lit("b"))])
    success = parser.parse.(Paco.State.from("abc"), parser)
    assert success.from == {0, 1, 1}
    assert success.to == {0, 1, 1}
  end
end
