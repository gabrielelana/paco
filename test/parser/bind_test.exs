defmodule Paco.Parser.BindTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "bind to a function" do
    parser = bind(lit("a"), fn(_) -> "b" end)
    assert parse(parser, "a") == {:ok, "b"}
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
  end

  test "boxing" do
    parser = bind("a", &String.duplicate(&1, 2))
    assert parse(parser, "a") == {:ok, "aa"}
  end

  test "fails if bind function raise an exception" do
    parser = bind(lit("a"), fn _  -> raise "boom!" end)
    assert parse(parser, "a") == {:error,
      ~s|error! bind function raised: boom! at 1:1|
    }
  end

  test "failure with description" do
    parser = bind(lit("a"), fn _  -> raise "boom!" end) |> as ("BIND")
    assert parse(parser, "a") == {:error,
      ~s|error! bind function (BIND) raised: boom! at 1:1|
    }
  end

  test "doesn't call bind function on failure" do
    parser = bind(lit("a"), fn(r) -> Process.put(:called, true); r end)
    parse(parser, "b")

    assert Process.get(:called, false) == false
  end
end
