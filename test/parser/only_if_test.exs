defmodule Paco.Parser.OnlyIfTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "success" do
    parser = integer |> only_if(&(&1 > 0))
    assert parse("42", parser) == {:ok, 42}
  end

  test "failure" do
    parser = integer |> only_if(&(&1 > 0))
    assert parse("0", parser) == {:error, "0 is not acceptable at 1:1"}
  end

  test "failure with description" do
    parser = integer |> only_if(&(&1 > 0)) |> as("ONLY IF")
    assert parse("0", parser) == {:error, "0 is not acceptable (ONLY IF) at 1:1"}
  end

  test "failure with message" do
    message = "expected a number greater than 0 %AT% but got %RESULT%"
    parser = integer |> only_if(fn n -> {n > 0, message} end)
    assert parse("0", parser) == {:error,
      "expected a number greater than 0 at 1:1 but got 0"
    }
  end

  defp integer do
    while("0123456789", at_least: 1) |> bind(&String.to_integer/1)
  end
end
