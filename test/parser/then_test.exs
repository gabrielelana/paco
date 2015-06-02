defmodule Paco.Parser.ThenTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "choose with a function" do
    parser = lit("a") |> then(fn s -> lit(s) end)

    assert parse(parser, "aa") == {:ok, "a"}

    assert describe(parser) == ~s|then(lit("a"), fn/1)|
  end

  test "choose with a function with result and state" do
    parser = lit("a")
             |> then(fn(s, %Paco.State{at: {_, ln, _}}) ->
                       while(s, ln)
                     end)

    parser = sequence_of([parser, skip(lit("\n")), parser])

    assert parse(parser, "aa\naaaa") == {:ok, ["a", "aa"]}
  end

  test "choose with a block" do
    parser = one_of([lit("a"), lit("b")])
             |> then do
                  "a" -> lit("a")
                  "b" -> lit("bb")
                end

    assert parse(parser, "aa") == {:ok, "a"}
    assert parse(parser, "bbb") == {:ok, "bb"}

    assert describe(parser) == ~s|then(one_of([lit("a"), lit("b")]), fn/1)|
  end

  test "autoboxing: given value and value returned from choose function are both boxed" do
    parser = then("a", fn _ -> "b" end)

    assert parse(parser, "ab") == {:ok, "b"}
  end

  test "fails if choose function raise an exception" do
    parser = then(lit("a"), fn _  -> raise "boom!" end)
    assert parse(parser, "a") == {:error,
      """
      Failed to match then(lit("a"), fn/1) at 1:1, \
      because it raised an exception: boom!
      """
    }
  end

  test "it doesn't show up in failure message" do
    parser = then(lit("a"), fn(s) -> lit(s) end)
    assert parse(parser, "b") == {:error,
      """
      Failed to match lit("a") at 1:1
      """
    }
  end

  test "doesn't call choose function on failure" do
    parser = then(lit("a"), fn(s) -> Process.put(:called, true); lit(s) end)
    parse(parser, "b")

    assert Process.get(:called, false) == false
  end

  test "notify events on success" do
    parser = then(lit("a"), fn(s) -> lit(s) end)

    Helper.assert_events_notified(parser, "aa", [
      {:started, ~s|then(lit("a"), fn/1)|},
      {:matched, {1, 1, 2}, {1, 1, 2}, {2, 1, 3}},
    ])
  end

  test "notify events on failure" do
    parser = then(lit("a"), fn(s) -> lit(s) end)

    Helper.assert_events_notified(parser, "b", [
      {:started, ~s|then(lit("a"), fn/1)|},
      {:failed, {0, 1, 1}},
    ])
  end
end
