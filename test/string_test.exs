defmodule Paco.StringTest do
  use ExUnit.Case, async: true

  import Paco.String

  test "consume" do
    assert consume("a", "a", {0, 1, 1}, {0, 1, 1}) == {{0, 1, 1}, {1, 1, 2}, ""}
    assert consume("aa", "aa", {0, 1, 1}, {0, 1, 1}) == {{1, 1, 2}, {2, 1, 3}, ""}
    assert consume("aaa", "aaa", {0, 1, 1}, {0, 1, 1}) == {{2, 1, 3}, {3, 1, 4}, ""}
    assert consume("aaa", "aaab", {0, 1, 1}, {0, 1, 1}) == {{2, 1, 3}, {3, 1, 4}, "b"}
  end

  test "consume with newlines" do
    assert consume("a\na", "a\na", {0, 1, 1}, {0, 1, 1}) == {{2, 2, 1}, {3, 2, 2}, ""}
    assert consume("\naa", "\naa", {0, 1, 1}, {0, 1, 1}) == {{2, 2, 2}, {3, 2, 3}, ""}
    assert consume("aa\n", "aa\n", {0, 1, 1}, {0, 1, 1}) == {{2, 1, 3}, {3, 2, 1}, ""}
    assert consume("aa\n", "aa\n\n", {0, 1, 1}, {0, 1, 1}) == {{2, 1, 3}, {3, 2, 1}, "\n"}
    assert consume("a\na\n", "a\na\n", {0, 1, 1}, {0, 1, 1}) == {{3, 2, 2}, {4, 3, 1}, ""}
  end

  test "consume with composed newlines" do
    assert consume("a\r\na", "a\r\na", {0, 1, 1}, {0, 1, 1}) == {{2, 2, 1}, {3, 2, 2}, ""}
  end

  test "seek" do
    assert seek("", "aaa", {0, 1, 1}, {0, 1, 1}, 3) == {"aaa", "", {2, 1, 3}, {3, 1, 4}}
    assert seek("", "aaab", {0, 1, 1}, {0, 1, 1}, 3) == {"aaa", "b", {2, 1, 3}, {3, 1, 4}}
    assert seek("", "a\na", {0, 1, 1}, {0, 1, 1}, 3) == {"a\na", "", {2, 2, 1}, {3, 2, 2}}
  end
end
