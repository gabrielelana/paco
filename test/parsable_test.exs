defmodule Paco.ParsableTest do
  use ExUnit.Case, async: true

  import Paco.Parser
  import Paco

  test "no effect on parsers" do
    assert parse("a", box(lit("a"))) == parse("a", lit("a"))
  end

  test "works on strings" do
    assert parse("a", box("a")) == parse("a", lit("a"))
  end

  test "works on regular expressions" do
    assert parse("a", box(~r/a/)) == parse("a", re(~r/a/))
  end

  test "works on atoms" do
    assert parse("a", box(:a)) == {:ok, :a}
  end

  test "nil is not parsed and always returned" do
    assert parse("a", box(nil)) == {:ok, nil}
  end

  test "works on tuples" do
    assert parse("a", box({lit("a")})) == {:ok, {"a"}}
    assert parse("ab", box({lit("a"), lit("b")})) == {:ok, {"a", "b"}}
    assert parse("a", box({})) == {:ok, {}}
  end

  test "works on lists" do
    assert parse("a", box([lit("a")])) == parse("a", sequence_of([lit("a")]))
    assert parse("ab", box([lit("a"), lit("b")])) == parse("ab", sequence_of([lit("a"), lit("b")]))
    assert parse("a", box([])) == parse("a", sequence_of([]))
  end

  test "works on maps" do
    parser = box(%{a: lit("a"), b: lit("b")})
    assert parse("ab", parser) == {:ok, %{a: "a", b: "b"}}

    parser = box(%{1 => lit("a"), 2 => lit("b")})
    assert parse("ab", parser) == {:ok, %{1 => "a", 2 => "b"}}

    parser = box(%{})
    assert parse("a", parser) == {:ok, %{}}
  end

  test "works on keywords" do
    parser = box([a: lit("a"), b: lit("b")])
    assert parse("ab", parser) == {:ok, [a: "a", b: "b"]}
  end

  defmodule Something do
    defstruct a: nil, b: nil
  end

  test "works on structs" do
    parser = box(%Something{a: lit("a"), b: lit("b")})
    assert parse("ab", parser) == {:ok, %Something{a: "a", b: "b"}}

    # nils are not parsed and kept in the struct
    parser = box(%Something{a: lit("a")})
    assert parse("ab", parser) == {:ok, %Something{a: "a"}}
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
    parser = box(%SomethingParsable{a: "a", b: "b"})
    assert parse("ab", parser) == {:ok, %SomethingParsable{a: "a", b: "b"}}
    assert parse("a b", parser) == {:ok, %SomethingParsable{a: "a", b: "b"}}
    assert parse(" ab ", parser) == {:ok, %SomethingParsable{a: "a", b: "b"}}
  end

  test "works recursively" do
    assert parse("a", box({"a"})) == {:ok, {"a"}}
    assert parse("a", box({~r/a/})) == {:ok, {"a"}}
    assert parse("abcd", box([{"a", "b"}, {"c", "d"}])) == {:ok, [{"a", "b"}, {"c", "d"}]}
  end
end
