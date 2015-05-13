defmodule PacoFormatTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "flat_tagged format of success (default)" do
    assert {:ok, <<_::binary>>} = parse(string("a"), "a", format: :flat_tagged)
    assert {:ok, <<_::binary>>} = parse(string("a"), "a")
  end

  test "flat_tagged format of failure (default)" do
    assert {:error, <<_::binary>>} = parse(string("a"), "b", format: :flat_tagged)
    assert {:error, <<_::binary>>} = parse(string("a"), "b")
  end

  test "flat format of success" do
    assert <<_::binary>> = parse(string("a"), "a", format: :flat)
  end

  test "flat format of failure" do
    assert <<_::binary>> = parse(string("a"), "b", format: :flat)
  end

  test "raw format of success" do
    assert %Paco.Success{} = parse(string("a"), "a", format: :raw)
  end

  test "raw format of failure" do
    assert %Paco.Failure{} = parse(string("a"), "b", format: :raw)
  end

  test "raw_tagged format of success" do
    assert {:ok, %Paco.Success{}} = parse(string("a"), "a", format: :raw_tagged)
  end

  test "raw_tagged format of failure" do
    assert {:error, %Paco.Failure{}} = parse(string("a"), "b", format: :raw_tagged)
  end
end
