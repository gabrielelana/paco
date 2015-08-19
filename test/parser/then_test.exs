defmodule Paco.Parser.ThenTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "choose parser with a function/1" do
    parser = lit("a") |> then(fn s -> lit(s) end)
    assert parse("aa", parser) == {:ok, "a"}
  end

  test "choose parser with a function/2" do
    parser = lit("a")
             |> then(fn(_, %Paco.Success{result: r}) ->
                       lit(r)
                     end)
    assert parse("aa", parser) == {:ok, "a"}
  end

  test "choose parser with a function/3" do
    parser = lit("a")
             |> then(fn(s, _, %Paco.State{at: {_, ln, _}}) ->
                       while(s, ln)
                     end)

    parser = sequence_of([parser, skip(lit("\n")), parser])

    assert parse("aa\naaa", parser) == {:ok, ["a", "aa"]}
  end

  test "parser is fixed, use the second parser only if the first succeeded" do
    parser = lit("a") |> then(lit("b"))

    assert parse("ab", parser) == {:ok, "b"}
    assert parse("bb", parser) == {:error, ~s|expected "a" at 1:1 but got "b"|}
  end

  test "boxing: the previous parser is boxed" do
    parser = then("a", fn _ -> lit("b") end)
    assert parse("ab", parser) == {:ok, "b"}
  end

  test "boxing: the next parser is boxed" do
    parser = then(lit("a"), "b")
    assert parse("ab", parser) == {:ok, "b"}
  end

  test "boxing: the result is boxed" do
    parser = then(lit("a"), fn _ -> "b" end)
    assert parse("ab", parser) == {:ok, "b"}
  end

  test "fails if function raise an exception" do
    parser = then(lit("a"), fn _  -> raise "boom!" end)
    assert parse("a", parser) == {:error,
      ~s|exception: boom! at 1:1|
    }
  end

  test "failure with description" do
    parser = then(lit("a"), fn _  -> raise "boom!" end) |> as("THEN")
    assert parse("a", parser) == {:error,
      ~s|exception: boom! (THEN) at 1:1|
    }
  end

  test "doesn't call choose function on failure" do
    parser = then(lit("a"), fn(s) -> Process.put(:called, true); lit(s) end)
    parse("b", parser)

    assert Process.get(:called, false) == false
  end
end
