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
    assert parse(parser, "0") == {:error, ~s|0 is not acceptable at 1:1|}
  end

  defp integer do
    while("0123456789", at_least: 1) |> bind(&String.to_integer/1)
  end
end
