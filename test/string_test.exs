defmodule Paco.StringTest do
  use ExUnit.Case, async: true

  import Paco.String

  test "consume" do
    assert consume("a", "a", {0, 1, 1}, {0, 1, 1}) == {{0, 1, 1}, {1, 1, 2}, ""}
    assert consume("aa", "aa", {0, 1, 1}, {0, 1, 1}) == {{1, 1, 2}, {2, 1, 3}, ""}
    assert consume("aaa", "aaa", {0, 1, 1}, {0, 1, 1}) == {{2, 1, 3}, {3, 1, 4}, ""}
    assert consume("aaa", "aaab", {0, 1, 1}, {0, 1, 1}) == {{2, 1, 3}, {3, 1, 4}, "b"}
    assert consume("a", "", {0, 1, 1}, {0, 1, 1}) == :end_of_input
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

  test "line_at" do
    assert line_at("", 0) == ""

    assert line_at("aaa", 0) == "aaa"
    assert line_at("aaa", 1) == "aaa"
    assert line_at("aaa", 2) == "aaa"
    assert line_at("aaa", 3) == ""

    assert line_at("a\nb\nc", 0) == "a"
    assert line_at("a\nb\nc", 1) == "a"
    assert line_at("a\nb\nc", 2) == "b"
    assert line_at("a\nb\nc", 3) == "b"
    assert line_at("a\nb\nc", 4) == "c"
    assert line_at("a\nb\nc", 5) == ""
  end

  test "consume_until a number of graphemes are counted" do
    assert consume_until("aaa", 1, {0, 1, 1}, {0, 1, 1}) == {"aa", {0, 1, 1}, {1, 1, 2}}
    assert consume_until("aaa", 2, {0, 1, 1}, {0, 1, 1}) == {"a", {1, 1, 2}, {2, 1, 3}}
    assert consume_until("aaa", 3, {0, 1, 1}, {0, 1, 1}) == {"", {2, 1, 3}, {3, 1, 4}}
    assert consume_until("a\na", 3, {0, 1, 1}, {0, 1, 1}) == {"", {2, 2, 1}, {3, 2, 2}}
    assert consume_until("aaa", 4, {0, 1, 1}, {0, 1, 1}) == :end_of_input
  end

  test "consume_until given function returns true" do
    assert consume_until("    ab", &whitespace?/1, {0, 1, 1}, {0, 1, 1}) == {"ab", {3, 1, 4}, {4, 1, 5}}
    assert consume_until("    ", &whitespace?/1, {0, 1, 1}, {0, 1, 1}) == {"", {3, 1, 4}, {4, 1, 5}}
    assert consume_until("a", &whitespace?/1, {0, 1, 1}, {0, 1, 1}) == {"a", {0, 1, 1}, {0, 1, 1}}
    assert consume_until("", &whitespace?/1, {0, 1, 1}, {0, 1, 1}) == {"", {0, 1, 1}, {0, 1, 1}}
  end
end
