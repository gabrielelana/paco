defmodule Paco.StringTest do
  use ExUnit.Case, async: true

  import Paco.String

  test "consume" do
    assert consume("a", "a", {0, 1, 1}) == {"", {0, 1, 1}, {1, 1, 2}}
    assert consume("aa", "aa", {0, 1, 1}) == {"", {1, 1, 2}, {2, 1, 3}}
    assert consume("aaa", "aaa", {0, 1, 1}) == {"", {2, 1, 3}, {3, 1, 4}}
    assert consume("aaab", "aaa", {0, 1, 1}) == {"b", {2, 1, 3}, {3, 1, 4}}
    assert consume("", "a", {0, 1, 1}) == :end_of_input
    assert consume("b", "a", {0, 1, 1}) == :error
  end

  test "consume with newlines" do
    assert consume("a\na", "a\na", {0, 1, 1}) == {"", {2, 2, 1}, {3, 2, 2}}
    assert consume("\naa", "\naa", {0, 1, 1}) == {"", {2, 2, 2}, {3, 2, 3}}
    assert consume("aa\n", "aa\n", {0, 1, 1}) == {"", {2, 1, 3}, {3, 2, 1}}
    assert consume("aa\n\n", "aa\n", {0, 1, 1}) == {"\n", {2, 1, 3}, {3, 2, 1}}
    assert consume("a\na\n", "a\na\n", {0, 1, 1}) == {"", {3, 2, 2}, {4, 3, 1}}
  end

  test "consume with composed newlines" do
    assert consume("a\r\na", "a\r\na", {0, 1, 1}) == {"", {2, 2, 1}, {3, 2, 2}}
  end

  test "consume_any" do
    assert consume_any("abc", 1, {0, 1, 1}) == {"a", "bc", {0, 1, 1}, {1, 1, 2}}
    assert consume_any("abc", 2, {0, 1, 1}) == {"ab", "c", {1, 1, 2}, {2, 1, 3}}
    assert consume_any("abc", 3, {0, 1, 1}) == {"abc", "", {2, 1, 3}, {3, 1, 4}}
    assert consume_any("a\nb", 3, {0, 1, 1}) == {"a\nb", "", {2, 2, 1}, {3, 2, 2}}
    assert consume_any("abc", 4, {0, 1, 1}) == :end_of_input
  end

  test "consume_while one of the allowed graphemes are matched" do
    assert consume_while("acbcd", "abc", {0, 1, 1}) == {"acbc", "d", {3, 1, 4}, {4, 1, 5}}
    assert consume_while("xxxxx", "abc", {0, 1, 1}) == {"", "xxxxx", {0, 1, 1}, {0, 1, 1}}
  end

  test "consume_while one of the allowed graphemes are matched for a number of times" do
    assert consume_while("acbcd", "abc", 2, {0, 1, 1}) == {"ac", "bcd", {1, 1, 2}, {2, 1, 3}}
    assert consume_while("xxxxx", "abc", 2, {0, 1, 1}) == :error
  end

  test "consume_while at the end of input" do
    assert consume_while("aaa", "a", {0, 1, 1}) == {"aaa", "", {2, 1, 3}, {3, 1, 4}}
  end

  test "consume_while a given function return true" do
    assert consume_while("    ab", &whitespace?/1, {0, 1, 1}) == {"    ", "ab", {3, 1, 4}, {4, 1, 5}}
    assert consume_while("    ", &whitespace?/1, {0, 1, 1}) == {"    ", "", {3, 1, 4}, {4, 1, 5}}
    assert consume_while("a", &whitespace?/1, {0, 1, 1}) == {"", "a", {0, 1, 1}, {0, 1, 1}}
    assert consume_while("", &whitespace?/1, {0, 1, 1}) == {"", "", {0, 1, 1}, {0, 1, 1}}
  end

  test "consume_while a given function return true for an exact number of times" do
    assert consume_while("aaa", &letter?/1, 1, {0, 1, 1}) == {"a", "aa", {0, 1, 1}, {1, 1, 2}}
    assert consume_while("aaa", &letter?/1, 2, {0, 1, 1}) == {"aa", "a", {1, 1, 2}, {2, 1, 3}}
    assert consume_while("aaa", &letter?/1, 3, {0, 1, 1}) == {"aaa", "", {2, 1, 3}, {3, 1, 4}}
    assert consume_while("aaa", &letter?/1, 4, {0, 1, 1}) == :end_of_input
    assert consume_while("aa%", &letter?/1, 3, {0, 1, 1}) == :error
  end

  test "consume_while a given function return true for minumum and a maximum number of times" do
    assert consume_while("a%%", &letter?/1, {1, :infinity}, {0, 1, 1}) == {"a", "%%", {0, 1, 1}, {1, 1, 2}}
    assert consume_while("a%%", &letter?/1, {2, :infinity}, {0, 1, 1}) == :error
    assert consume_while("", &letter?/1, {1, :infinity}, {0, 1, 1}) == :end_of_input
    assert consume_while("abc", &letter?/1, {1, 2}, {0, 1, 1}) == {"ab", "c", {1, 1, 2}, {2, 1, 3}}
    assert consume_while("abc", &letter?/1, {1, 4}, {0, 1, 1}) == {"abc", "", {2, 1, 3}, {3, 1, 4}}
    assert consume_while("abc", &letter?/1, {5, 6}, {0, 1, 1}) == :end_of_input
  end

  test "consume_until given function returns true" do
    assert consume_until("abc   ", &whitespace?/1, {0, 1, 1}) == {"abc", "   ", {2, 1, 3}, {3, 1, 4}}
    assert consume_until("abc", &whitespace?/1, {0, 1, 1}) == {"abc", "", {2, 1, 3}, {3, 1, 4}}
    assert consume_until("", &whitespace?/1, {0, 1, 1}) == {"", "", {0, 1, 1}, {0, 1, 1}}
  end

  test "consume_until a boundary" do
    assert consume_until("a[b]", "[", {0, 1, 1}) == {"a", "[b]", {0, 1, 1}, {1, 1, 2}}
    assert consume_until("aaa[b]", "[", {0, 1, 1}) == {"aaa", "[b]", {2, 1, 3}, {3, 1, 4}}
    assert consume_until("aaa", "[", {0, 1, 1}) == {"aaa", "", {2, 1, 3}, {3, 1, 4}}
  end

  test "consume_until a boundary with more than one character" do
    assert consume_until("aaabbb", "bbb", {0, 1, 1}) == {"aaa", "bbb", {2, 1, 3}, {3, 1, 4}}
    assert consume_until("aaa", "bbb", {0, 1, 1}) == {"aaa", "", {2, 1, 3}, {3, 1, 4}}
  end

  test "consume_until a boundary with escape" do
    assert consume_until("a\\[b[c]", {"[", "\\"}, {0, 1, 1}) == {"a\\[b", "[c]", {3, 1, 4}, {4, 1, 5}}
    assert consume_until("abc", {"[", "\\"}, {0, 1, 1}) == {"abc", "", {2, 1, 3}, {3, 1, 4}}
    assert consume_until("abc\\", {"[", "\\"}, {0, 1, 1}) == {"abc\\", "", {3, 1, 4}, {4, 1, 5}}
  end

  test "consume_until a boundary with escape with more than one character" do
    assert consume_until("a<ESCAPE>[b[c]", {"[", "<ESCAPE>"}, {0, 1, 1}) ==
           {"a<ESCAPE>[b", "[c]", {10, 1, 11}, {11, 1, 12}}
  end

  test "seek" do
    assert seek("aaa", {0, 1, 1}, 3) == {"aaa", "", {2, 1, 3}, {3, 1, 4}}
    assert seek("aaab", {0, 1, 1}, 3) == {"aaa", "b", {2, 1, 3}, {3, 1, 4}}
    assert seek("a\na", {0, 1, 1}, 3) == {"a\na", "", {2, 2, 1}, {3, 2, 2}}
  end

  test "line_at" do
    assert line_at("", 0) == ""

    assert line_at("aaa", 0) == "aaa"
    assert line_at("aaa", 1) == "aaa"
    assert line_at("aaa", 2) == "aaa"
    assert line_at("aaa", 3) == "aaa"

    assert line_at("a\nb\nc", 0) == "a"
    assert line_at("a\nb\nc", 1) == "a"
    assert line_at("a\nb\nc", 2) == "b"
    assert line_at("a\nb\nc", 3) == "b"
    assert line_at("a\nb\nc", 4) == "c"
    assert line_at("a\nb\nc", 5) == "c"
  end
end
