defmodule Paco.ASCIITest do
  use ExUnit.Case, async: true

  import Paco.ASCII

  test "lower" do
    assert "l" in lower
    assert lower?("l")
    assert downcase?("l")
    refute lower?("L")
  end

  test "upper" do
    assert "L" in upper
    assert upper?("L")
    assert upcase?("L")
    refute upper?("l")
  end

  test "letter" do
    assert "L" in letter
    assert letter?("L")
    assert "l" in letter
    assert letter?("l")
  end

  test "punctuation" do
    assert "." in punctuation
    assert punctuation?(".")
    assert punct?(".")
    refute punct?("a")
  end
end
