defmodule PacoTest do
  use ExUnit.Case, async: true

  import Paco.Parser

  test "parse with autoboxing" do
    assert Paco.parse("a", "a") == {:ok, "a"}
  end

  test "skipped parsers returns empty result" do
    assert Paco.parse(skip(lit("a")), "a") == {:ok, ""}
  end

  test "parse_all" do
    parser = one_of([lit("a"), lit("b"), lit("c")])

    assert Paco.parse_all(parser, "a") == [{:ok, "a"}]
    assert Paco.parse_all(parser, "ab") == [{:ok, "a"}, {:ok, "b"}]
    assert Paco.parse_all(parser, "abc") == [{:ok, "a"}, {:ok, "b"}, {:ok, "c"}]
    assert Paco.parse_all(parser, "abcb") == [{:ok, "a"}, {:ok, "b"}, {:ok, "c"}, {:ok, "b"}]
  end

  test "parse_all stops at the first failure" do
    assert Paco.parse_all(lit("a"), "baa") == [
      {:error, ~s|expected "a" at 1:1 but got "b"|}
    ]
    assert Paco.parse_all(lit("a"), "aba") == [
      {:ok, "a"}, {:error, ~s|expected "a" at 1:2 but got "b"|}
    ]
    assert Paco.parse_all(lit("a"), "aab") == [
      {:ok, "a"}, {:ok, "a"}, {:error, ~s|expected "a" at 1:3 but got "b"|}
    ]
  end

  test "parse_all will consider failure an empty match" do
    assert Paco.parse_all(lit(""), "abc") == [{:error,
        ~s|failure! parser didn't consume any input|
    }]
  end

  test "parse_all with flat format" do
    assert Paco.parse_all(lit("a"), "aaa", format: :flat) == ["a", "a", "a"]
    assert Paco.parse_all(lit("a"), "afa", format: :flat) == [
      "a", ~s|expected "a" at 1:2 but got "f"|
    ]
  end

  test "parse_all with raw format" do
    alias Paco.Success, as: S
    alias Paco.Failure, as: F

    assert [%S{}, %S{}, %S{}] = Paco.parse_all(lit("a"), "aaa", format: :raw)
    assert [%S{}, %F{}] = Paco.parse_all(lit("a"), "aba", format: :raw)
  end

  test "parse_all with raise on failure option" do
    assert_raise Paco.Failure,
                 ~s|expected "a" at 1:2 but got "b"|,
                 fn ->
                   Paco.parse_all(lit("a"), "aba", on_failure: :raise)
                 end
  end

  test "parse_all! same as parse_all with raise on failure option" do
    assert_raise Paco.Failure,
                 ~s|expected "a" at 1:2 but got "b"|,
                 fn ->
                   Paco.parse_all!(lit("a"), "aba")
                 end
  end
end
