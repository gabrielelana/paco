defmodule Paco.ParsableTest do
  use ExUnit.Case, async: true

  import Paco.Parser
  import Paco

  test "no effect on parsers" do
    assert parse(from(lit("a")), "a") == parse(lit("a"), "a")
  end

  test "works on strings" do
    assert parse(from("a"), "a") == parse(lit("a"), "a")
  end

  test "works on regular expressions" do
    assert parse(from(~r/a/), "a") == parse(rex(~r/a/), "a")
  end

  test "works on atoms" do
    assert parse(from(:a), "a") == {:ok, :a}
  end

  test "nil is not parsed and always returned" do
    assert parse(from(nil), "a") == {:ok, nil}
  end

  test "works on tuples" do
    assert parse(from({lit("a")}), "a") == {:ok, {"a"}}
    assert parse(from({lit("a"), lit("b")}), "ab") == {:ok, {"a", "b"}}
    assert parse(from({}), "a") == {:ok, {}}
  end

  test "works on lists" do
    assert parse(from([lit("a")]), "a") == parse(sequence_of([lit("a")]), "a")
    assert parse(from([lit("a"), lit("b")]), "ab") == parse(sequence_of([lit("a"), lit("b")]), "ab")
    assert parse(from([]), "a") == parse(sequence_of([]), "a")
  end

  test "works on maps" do
    parser = from(%{a: lit("a"), b: lit("b")})
    assert parse(parser, "ab") == {:ok, %{a: "a", b: "b"}}

    parser = from(%{1 => lit("a"), 2 => lit("b")})
    assert parse(parser, "ab") == {:ok, %{1 => "a", 2 => "b"}}

    parser = from(%{})
    assert parse(parser, "a") == {:ok, %{}}
  end

  test "works on keywords" do
    parser = from([a: lit("a"), b: lit("b")])
    assert parse(parser, "ab") == {:ok, [a: "a", b: "b"]}
  end

  defmodule Something do
    defstruct a: nil, b: nil
  end

  test "works on structs" do
    parser = from(%Something{a: lit("a"), b: lit("b")})
    assert parse(parser, "ab") == {:ok, %Something{a: "a", b: "b"}}

    # nils are not parsed and kept in the struct
    parser = from(%Something{a: lit("a")})
    assert parse(parser, "ab") == {:ok, %Something{a: "a"}}
  end

  defmodule SomethingParsable do
    defstruct a: nil, b: nil
  end

  defimpl Paco.Parsable, for: SomethingParsable do
    def to_parser(something) do
      sequence_of([lex(something.a), lex(something.b)])
      |> bind(fn [a, b] -> %SomethingParsable{a: a, b: b} end)
    end
  end

  test "works on structs that implements the protocol" do
    parser = from(%SomethingParsable{a: "a", b: "b"})
    assert parse(parser, "ab") == {:ok, %SomethingParsable{a: "a", b: "b"}}
    assert parse(parser, "a b") == {:ok, %SomethingParsable{a: "a", b: "b"}}
    assert parse(parser, " ab ") == {:ok, %SomethingParsable{a: "a", b: "b"}}
  end

  test "works recursively" do
    assert parse(from({"a"}), "a") == {:ok, {"a"}}
    assert parse(from({~r/a/}), "a") == {:ok, {"a"}}
    assert parse(from([{"a", "b"}, {"c", "d"}]), "abcd") == {:ok, [{"a", "b"}, {"c", "d"}]}
  end
end
