defmodule Paco.Parser.Label.Test do
  use ExUnit.Case

  import Paco
  import Paco.Parser

  test "label the name of a parser" do
    assert label(string("a"), "an a").name == "an a"
  end

  test "describe" do
    assert describe(label(string("a"), "an a")) == "an a"
  end

  test "label shows up in the failure message" do
    labeled = label(string("a"), "an a")
    {:error, failure} = parse(labeled, "b")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match an a at 1:1
      """
  end
end
