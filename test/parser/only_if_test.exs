defmodule Paco.Parser.OnlyIfTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "success" do
    parser = integer |> only_if(&(&1 > 0))

    assert parse(parser, "42") == {:ok, 42}
  end

  test "failure" do
    parser = integer |> only_if(&(&1 > 0))

    assert parse(parser, "0") == {:error,
      """
      Failed to match only_if(bind(while(\"0123456789\", {1, :infinity}), &:erlang.binary_to_integer/1), fn/1) at 1:1, \
      because it considered 0 not acceptable
      """
    }
  end

  test "fails if function raises an exception" do
    parser = lit("a") |> only_if(fn _  -> raise "boom!" end)
    assert parse(parser, "a") == {:error,
      """
      Failed to match only_if(lit("a"), fn/1) at 1:1, \
      because it raised an exception: boom!
      """
    }
  end

  defp integer do
    while("0123456789", {:at_least, 1}) |> bind(&String.to_integer/1)
  end
end
