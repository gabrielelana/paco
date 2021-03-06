defmodule Paco.Parser.FailWithTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "replace failure with direct message" do
    parser = lit("alien") |> fail_with("I don't see any alien")
    assert parse("cool", parser) == {:error, "I don't see any alien"}
  end

  test "replace failure with message with tokens" do
    parser = lit("alien") |> fail_with("I don't see any %EXPECTED%")
    assert parse("cool", parser) == {:error, ~s|I don't see any "alien"|}
  end
end
