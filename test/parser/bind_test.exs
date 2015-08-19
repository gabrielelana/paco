defmodule Paco.Parser.BindTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "bind to a function" do
    parser = bind(lit("a"), fn(_) -> "b" end)
    assert parse("a", parser) == {:ok, "b"}
  end

  test "bind to a function/2" do
    parser = bind(lit("a"), fn(_, %Paco.Success{result: r}) -> r end)
    assert parse("a", parser) == {:ok, "a"}
  end

  test "bind to a function/3" do
    parser = bind(lit("a"), fn(_, _, %Paco.State{at: at}) -> at end)
    assert parse("a", parser) == {:ok, {1, 1, 2}}
  end

  test "bind can terminate with a failure" do
    parser = lit("a") |> bind(fn(_, _, state) ->
                                Paco.Failure.at(state, message: "bind gone wrong")
                              end)

    assert parse("a", parser) == {:error, ~s|bind gone wrong|}
  end

  test "bind can terminate with a success" do
    parser = lit("a") |> bind(fn(_, success, _) ->
                                success
                              end)

    assert parse("a", parser) == {:ok, "a"}
  end

  test "boxing" do
    parser = bind("a", &String.duplicate(&1, 2))
    assert parse("a", parser) == {:ok, "aa"}
  end

  test "fails if bind function raise an exception" do
    parser = bind(lit("a"), fn _  -> raise "boom!" end)
    assert parse("a", parser) == {:error,
      ~s|exception: boom! at 1:1|
    }
  end

  test "failure with description" do
    parser = bind(lit("a"), fn _  -> raise "boom!" end) |> as("BIND")
    assert parse("a", parser) == {:error,
      ~s|exception: boom! (BIND) at 1:1|
    }
  end

  test "doesn't call bind function on failure" do
    parser = bind(lit("a"), fn(r) -> Process.put(:called, true); r end)
    parse("b", parser)

    assert Process.get(:called, false) == false
  end
end
