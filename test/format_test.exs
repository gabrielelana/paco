defmodule PacoFormatTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "tagged format of success (default)" do
    assert {:ok, <<_::binary>>} = parse("a", lit("a"), format: :tagged)
    assert {:ok, <<_::binary>>} = parse("a", lit("a"))
  end

  test "tagged format of failure (default)" do
    assert {:error, <<_::binary>>} = parse("b", lit("a"), format: :tagged)
    assert {:error, <<_::binary>>} = parse("b", lit("a"))
  end

  test "flat format of success" do
    assert <<_::binary>> = parse("a", lit("a"), format: :flat)
  end

  test "flat format of failure" do
    assert <<_::binary>> = parse("b", lit("a"), format: :flat)
  end

  test "raw format of success" do
    assert %Paco.Success{} = parse("a", lit("a"), format: :raw)
  end

  test "raw format of failure" do
    assert %Paco.Failure{} = parse("b", lit("a"), format: :raw)
  end
end
