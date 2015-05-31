defmodule Paco.Parser.BindTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "bind to a function" do
    parser = bind(lit("a"), fn(_) -> "b" end)

    assert parse(parser, "a") == {:ok, "b"}

    assert describe(parser) == ~s|bind(lit("a"), fn/1)|
  end

  test "bind to a function with result and state" do
    parser = bind(lit("a"), fn(_, %Paco.State{at: at}) -> at end)
    assert parse(parser, "a") == {:ok, {1, 1, 2}}
  end

  test "bind to a block" do
    parser = one_of([lit("a"), lit("b")])
             |> bind do
                 "a" -> 1
                 "b" -> 2
                end

    assert parse(parser, "a") == {:ok, 1}
    assert parse(parser, "b") == {:ok, 2}

    assert describe(parser) == ~s|bind(one_of([lit("a"), lit("b")]), fn/1)|
  end

  test "bind to a block with result and state" do
    parser = one_of([lit("a"), lit("bb")])
             |> bind :result_and_state do
                  {_, %Paco.State{at: at}} -> at
                end

    assert parse(parser, "a") == {:ok, {1, 1, 2}}
    assert parse(parser, "bb") == {:ok, {2, 1, 3}}
  end

  test "bind to an inline block" do
    parser = one_of([lit("a"), lit("b")])
             |> (bind do: ("a" -> 1; "b" -> 2))

    assert parse(parser, "a") == {:ok, 1}
    assert parse(parser, "b") == {:ok, 2}

    assert describe(parser) == ~s|bind(one_of([lit("a"), lit("b")]), fn/1)|
  end

  test "failure" do
    parser = bind(lit("a"), fn(r) -> r end)
    assert parse(parser, "b") == {:error,
      """
      Failed to match lit("a") at 1:1
      """
    }
  end

  test "ignore failure" do
    parser = bind(lit("a"), fn(r) -> Process.put(:called, true); r end)
    parse(parser, "b")
    assert Process.get(:called, false) == false
  end

  test "notify events on success" do
    parser = bind(lit("a"), fn(r) -> r end)

    Helper.assert_events_notified(parser, "a", [
      {:started, ~s|bind(lit("a"), fn/1)|},
      {:matched, {0, 1, 1}, {0, 1, 1}, {1, 1, 2}},
    ])
  end

  test "notify events on failure" do
    parser = bind(lit("a"), fn(r) -> r end)

    Helper.assert_events_notified(parser, "b", [
      {:started, ~s|bind(lit("a"), fn/1)|},
      {:failed, {0, 1, 1}},
    ])
  end

end
