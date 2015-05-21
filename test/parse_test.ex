defmodule PacoTest do
  use ExUnit.Case, async: true

  import Paco.Parser

  test "parse_all" do
    parser = one_of([lit("a"), lit("b"), lit("c")])

    assert Paco.parse_all(parser, "a") == [{:ok, "a"}]
    assert Paco.parse_all(parser, "ab") == [{:ok, "a"}, {:ok, "b"}]
    assert Paco.parse_all(parser, "abc") == [{:ok, "a"}, {:ok, "b"}, {:ok, "c"}]
    assert Paco.parse_all(parser, "abcb") == [{:ok, "a"}, {:ok, "b"}, {:ok, "c"}, {:ok, "b"}]
  end

  test "parse_all stops at the first failure" do
    parser = one_of([lit("a"), lit("b"), lit("c")])

    assert Paco.parse_all(parser, "afa") == [{:ok, "a"}, {:error,
      """
      Failed to match one_of#4([lit#1, lit#2, lit#3]) at 1:2
      """
    }]
    assert Paco.parse_all(parser, "abfa") == [{:ok, "a"}, {:ok, "b"}, {:error,
      """
      Failed to match one_of#4([lit#1, lit#2, lit#3]) at 1:3
      """
    }]
    assert [{:ok, "a"}, {:ok, "b"}, {:error, _}] = Paco.parse_all(parser, "abfa")
  end

  test "parse_all with flat format" do
    parser = one_of([lit("a"), lit("b"), lit("c")])

    assert Paco.parse_all(parser, "abc", format: :flat) == ["a", "b", "c"]
    assert Paco.parse_all(parser, "afa", format: :flat) == ["a",
      """
      Failed to match one_of#4([lit#1, lit#2, lit#3]) at 1:2
      """
    ]
  end

  test "parse_all with raw format" do
    parser = one_of([lit("a"), lit("b"), lit("c")])
    alias Paco.Success, as: S
    alias Paco.Failure, as: F

    assert [%S{}, %S{}, %S{}] = Paco.parse_all(parser, "abc", format: :raw)
    assert [%S{}, %F{}] = Paco.parse_all(parser, "afc", format: :raw)
  end

  test "parse_all with raise on failure option" do
    parser = one_of([lit("a"), lit("b"), lit("c")])

    assert_raise Paco.Failure,
                 """
                 Failed to match one_of#4([lit#1, lit#2, lit#3]) at 1:2
                 """,
                 fn ->
                   Paco.parse_all(parser, "afc", on_failure: :raise)
                 end
  end

  test "parse_all! same as parse_all with raise on failure option" do
    parser = one_of([lit("a"), lit("b"), lit("c")])

    assert_raise Paco.Failure,
                 """
                 Failed to match one_of#4([lit#1, lit#2, lit#3]) at 1:2
                 """,
                 fn ->
                   Paco.parse_all!(parser, "afc")
                 end
  end

end
