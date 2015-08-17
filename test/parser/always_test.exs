defmodule Paco.Parser.AlwaysTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "always succeed" do
    assert parse(always("a"), "a") == {:ok, "a"}
    assert parse(always("a"), "b") == {:ok, "a"}
    assert parse(always("a"), "") == {:ok, "a"}
    assert parse(always(:anything), "") == {:ok, :anything}
    assert parse(always(nil), "") == {:ok, nil}
  end

  test "doesn't consume any input" do
    parser = always("something")
    success = parser.parse.(Paco.State.from("a"), parser)
    assert success.at == {0, 1, 1}
    assert success.tail == "a"
  end
end
