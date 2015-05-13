defmodule PacoFormatTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "flat_tagged format of success (default)" do
    assert parse(string("a"), "a", format: :flat_tagged) == {:ok, "a"}
    assert parse(string("a"), "a") == {:ok, "a"}
  end

  test "flat_tagged format of failure (default)" do
    assert parse(string("a"), "b", format: :flat_tagged) == {:error, "Failed to match string(a) at 1:1\n"}
    assert parse(string("a"), "b") == {:error, "Failed to match string(a) at 1:1\n"}
  end

  test "flat format of success" do
    assert parse(string("a"), "a", format: :flat) == "a"
  end

  test "flat format of failure" do
    assert parse(string("a"), "b", format: :flat) == "Failed to match string(a) at 1:1\n"
  end
end
