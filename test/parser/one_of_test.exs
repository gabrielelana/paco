defmodule Paco.Parser.OneOfTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse one of the parsers" do
    assert parse(one_of([lit("a"), lit("b"), lit("c")]), "a") == {:ok, "a"}
    assert parse(one_of([lit("a"), lit("b"), lit("c")]), "b") == {:ok, "b"}
    assert parse(one_of([lit("a"), lit("b"), lit("c")]), "c") == {:ok, "c"}
    assert parse(one_of([lit("a")]), "a") == {:ok, "a"}
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
    # TODO
    # parser = one_of([lit("ab"), lit("bc")])

    # assert parse(parser, "ac") == {:error,
    #   ~s|expected "ab" at 1:1 but got "ac"|
    # }
    # assert parse(parser, "ba") == {:error,
    #   ~s|expected "bc" at 1:1 but got "ba"|
    # }
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

  test "keep all contending failures" do
    # TODO
  end

  test "report position of the farthest failure" do
    parser = one_of([sequence_of([lit("a"), lit("b")]),
                     sequence_of([lit("b"), lit("c")])])
    failure = parser.parse.(Paco.State.from("ac"), parser)
    assert failure.at == {1, 1, 2}
    assert failure.tail == "c"
  end
end
