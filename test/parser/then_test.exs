defmodule Paco.Parser.ThenTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "choose next parser with a function" do
    parser = lit("a") |> then(fn s -> lit(s) end)
    assert parse(parser, "aa") == {:ok, "a"}
  end

  test "choose next parser with a function with result and state" do
    parser = lit("a")
             |> then(fn(s, %Paco.State{at: {_, ln, _}}) ->
                       while(s, ln)
                     end)

    parser = sequence_of([parser, skip(lit("\n")), parser])

    assert parse(parser, "aa\naaa") == {:ok, ["a", "aa"]}
  end

  test "choose next parser with a block" do
    parser = one_of([lit("a"), lit("b")])
             |> then do
                  "a" -> lit("a")
                  "b" -> lit("bb")
                end

    assert parse(parser, "aa") == {:ok, "a"}
    assert parse(parser, "bbb") == {:ok, "bb"}
  end

  test "boxing: the parameter and the return value are both boxed" do
    parser = then("a", fn _ -> "b" end)
    assert parse(parser, "ab") == {:ok, "b"}
  end

  test "fails if function raise an exception" do
    parser = then(lit("a"), fn _  -> raise "boom!" end)
    assert parse(parser, "a") == {:error,
      ~s|exception: boom! at 1:1|
    }
  end

  test "failure with description" do
    parser = then(lit("a"), fn _  -> raise "boom!" end) |> as("THEN")
    assert parse(parser, "a") == {:error,
      ~s|exception: boom! (THEN) at 1:1|
    }
  end

  test "doesn't call choose function on failure" do
    parser = then(lit("a"), fn(s) -> Process.put(:called, true); lit(s) end)
    parse(parser, "b")

    assert Process.get(:called, false) == false
  end
end
