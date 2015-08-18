defmodule Paco.StringTest do
  use ExUnit.Case, async: true

  import Paco.String
  import Paco.ASCII, only: [whitespace?: 1, letter?: 1]

  test "consume" do
    assert consume("a", "a", {0, 1, 1}) == {"", "a", {0, 1, 1}, {1, 1, 2}}
    assert consume("aa", "aa", {0, 1, 1}) == {"", "aa", {1, 1, 2}, {2, 1, 3}}
    assert consume("aaa", "aaa", {0, 1, 1}) == {"", "aaa", {2, 1, 3}, {3, 1, 4}}
    assert consume("aaab", "aaa", {0, 1, 1}) == {"b", "aaa", {2, 1, 3}, {3, 1, 4}}
    assert consume("", "aa", {0, 1, 1}) == {:not_enough, "", "", {0, 1, 1}, {0, 1, 1}}
    assert consume("a", "aa", {0, 1, 1}) == {:not_enough, "", "a", {0, 1, 1}, {1, 1, 2}}
    assert consume("ab", "aa", {0, 1, 1}) == {:not_expected, "b", "a", {0, 1, 1}, {1, 1, 2}}
  end

  test "consume with newlines" do
    assert consume("a\na", "a\na", {0, 1, 1}) == {"", "a\na", {2, 2, 1}, {3, 2, 2}}
    assert consume("\naa", "\naa", {0, 1, 1}) == {"", "\naa", {2, 2, 2}, {3, 2, 3}}
    assert consume("aa\n", "aa\n", {0, 1, 1}) == {"", "aa\n", {2, 1, 3}, {3, 2, 1}}
    assert consume("aa\n\n", "aa\n", {0, 1, 1}) == {"\n", "aa\n", {2, 1, 3}, {3, 2, 1}}
    assert consume("a\na\n", "a\na\n", {0, 1, 1}) == {"", "a\na\n", {3, 2, 2}, {4, 3, 1}}
  end

  test "consume with composed newlines" do
    assert consume("a\r\na", "a\r\na", {0, 1, 1}) == {"", "a\r\na", {2, 2, 1}, {3, 2, 2}}
  end

  test "consume_any graphemes for an exact number of times" do
    assert consume_any("abc", 2, {0, 1, 1}) == {"c", "ab", {1, 1, 2}, {2, 1, 3}}
    assert consume_any("abc", 3, {0, 1, 1}) == {"", "abc", {2, 1, 3}, {3, 1, 4}}
    assert consume_any("a\nb", 3, {0, 1, 1}) == {"", "a\nb", {2, 2, 1}, {3, 2, 2}}

    assert consume_any("", 1, {0, 1, 1}) == {:not_enough, "", "", {0, 1, 1}, {0, 1, 1}}
    assert consume_any("abc", 4, {0, 1, 1}) == {:not_enough, "", "abc", {2, 1, 3}, {3, 1, 4}}
    assert consume_any("abc", 4, {0, 1, 1}) == {:not_enough, "", "abc", {2, 1, 3}, {3, 1, 4}}
  end

  test "consume_any graphemes for a certain number of times" do
    assert consume_any("abc", {0, 1}, {0, 1, 1}) == {"bc", "a", {0, 1, 1}, {1, 1, 2}}
    assert consume_any("abc", {0, 2}, {0, 1, 1}) == {"c", "ab", {1, 1, 2}, {2, 1, 3}}
    assert consume_any("abc", {0, 3}, {0, 1, 1}) == {"", "abc", {2, 1, 3}, {3, 1, 4}}
    assert consume_any("abc", {0, 4}, {0, 1, 1}) == {"", "abc", {2, 1, 3}, {3, 1, 4}}
    assert consume_any("abc", {0, :infinity}, {0, 1, 1}) == {"", "abc", {2, 1, 3}, {3, 1, 4}}
    assert consume_any("abc", {1, :infinity}, {0, 1, 1}) == {"", "abc", {2, 1, 3}, {3, 1, 4}}
    assert consume_any("abc", {2, :infinity}, {0, 1, 1}) == {"", "abc", {2, 1, 3}, {3, 1, 4}}
    assert consume_any("abc", {3, :infinity}, {0, 1, 1}) == {"", "abc", {2, 1, 3}, {3, 1, 4}}

    assert consume_any("abc", {4, :infinity}, {0, 1, 1}) == {:not_enough, "", "abc", {2, 1, 3}, {3, 1, 4}}
  end

  test "consume_while one of the allowed graphemes are matched" do
    assert consume_while("acbc", "abc", {0, 1, 1}) == {"", "acbc", {3, 1, 4}, {4, 1, 5}}
    assert consume_while("acbcd", "abc", {0, 1, 1}) == {"d", "acbc", {3, 1, 4}, {4, 1, 5}}
    assert consume_while("xxxxx", "abc", {0, 1, 1}) == {"xxxxx", "", {0, 1, 1}, {0, 1, 1}}
  end

  test "consume_while one of the allowed graphemes in list are matched" do
    assert consume_while("acbc", ["a", "b", "c"], {0, 1, 1}) == {"", "acbc", {3, 1, 4}, {4, 1, 5}}
    assert consume_while("acbcd", ["a", "b", "c"], {0, 1, 1}) == {"d", "acbc", {3, 1, 4}, {4, 1, 5}}
    assert consume_while("xxxxx", ["a", "b", "c"], {0, 1, 1}) == {"xxxxx", "", {0, 1, 1}, {0, 1, 1}}
  end

  test "consume_while a given function returns true" do
    assert consume_while("    ab", &whitespace?/1, {0, 1, 1}) == {"ab", "    ", {3, 1, 4}, {4, 1, 5}}
    assert consume_while("    ", &whitespace?/1, {0, 1, 1}) == {"", "    ", {3, 1, 4}, {4, 1, 5}}
    assert consume_while("a", &whitespace?/1, {0, 1, 1}) == {"a", "", {0, 1, 1}, {0, 1, 1}}
    assert consume_while("", &whitespace?/1, {0, 1, 1}) == {"", "", {0, 1, 1}, {0, 1, 1}}
  end

  test "consume_while one of the allowed graphemes are matched for an exact number of times" do
    assert consume_while("acbcd", "abc", 2, {0, 1, 1}) == {"bcd", "ac", {1, 1, 2}, {2, 1, 3}}
    assert consume_while("xxxxx", "abc", 2, {0, 1, 1}) == {:not_enough, "xxxxx", "", {0, 1, 1}, {0, 1, 1}}
    assert consume_while("a", "abc", 2, {0, 1, 1}) == {:not_enough, "", "a", {0, 1, 1}, {1, 1, 2}}
  end

  test "consume_while a given function return true for an exact number of times" do
    assert consume_while("aaa", &letter?/1, 1, {0, 1, 1}) == {"aa", "a", {0, 1, 1}, {1, 1, 2}}
    assert consume_while("aaa", &letter?/1, 2, {0, 1, 1}) == {"a", "aa", {1, 1, 2}, {2, 1, 3}}
    assert consume_while("aaa", &letter?/1, 3, {0, 1, 1}) == {"", "aaa", {2, 1, 3}, {3, 1, 4}}
    assert consume_while("aaa", &letter?/1, 4, {0, 1, 1}) == {:not_enough, "", "aaa", {2, 1, 3}, {3, 1, 4}}
    assert consume_while("aa%", &letter?/1, 3, {0, 1, 1}) == {:not_enough, "%", "aa", {1, 1, 2}, {2, 1, 3}}
  end

  test "consume_while one of the allowed graphemes are matched for a certain number times" do
    assert consume_while("", "abc", {1, :infinity}, {0, 1, 1}) == {:not_enough, "", "", {0, 1, 1}, {0, 1, 1}}
    assert consume_while("xxxxx", "abc", {1, :infinity}, {0, 1, 1}) == {:not_enough, "xxxxx", "", {0, 1, 1}, {0, 1, 1}}
    assert consume_while("aaxxx", "abc", {3, :infinity}, {0, 1, 1}) == {:not_enough, "xxx", "aa", {1, 1, 2}, {2, 1, 3}}
    assert consume_while("abcabc", "abc", {1, 3}, {0, 1, 1}) == {"abc", "abc", {2, 1, 3}, {3, 1, 4}}
  end

  test "consume_while a given function returns true for a certain number times" do
    assert consume_while("", &letter?/1, {1, :infinity}, {0, 1, 1}) == {:not_enough, "", "", {0, 1, 1}, {0, 1, 1}}
    assert consume_while("aa", &letter?/1, {3, :infinity}, {0, 1, 1}) == {:not_enough, "", "aa", {1, 1, 2}, {2, 1, 3}}
    assert consume_while("abcabc", &letter?/1, {1, 3}, {0, 1, 1}) == {"abc", "abc", {2, 1, 3}, {3, 1, 4}}
  end

  test "consume_until a boundary" do
    assert consume_until("a[b]", "[", {0, 1, 1}) == {"[b]", "a", {0, 1, 1}, {1, 1, 2}}
    assert consume_until("aaa[b]", "[", {0, 1, 1}) == {"[b]", "aaa", {2, 1, 3}, {3, 1, 4}}
    assert consume_until("aaa[", "[", {0, 1, 1}) == {"[", "aaa", {2, 1, 3}, {3, 1, 4}}

    assert consume_until("", "[", {0, 1, 1}) == {:not_enough, "", "", {0, 1, 1}, {0, 1, 1}}
    assert consume_until("aaa", "[", {0, 1, 1}) == {:not_enough, "", "aaa", {2, 1, 3}, {3, 1, 4}}
  end

  test "consume_until multiple boundaries" do
    boundaries = ["[", ";"]

    assert consume_until("a[b]", boundaries, {0, 1, 1}) == {"[b]", "a", {0, 1, 1}, {1, 1, 2}}
    assert consume_until("a;b", boundaries, {0, 1, 1}) == {";b", "a", {0, 1, 1}, {1, 1, 2}}
    assert consume_until("a;[b]", boundaries, {0, 1, 1}) == {";[b]", "a", {0, 1, 1}, {1, 1, 2}}

    assert consume_until("", boundaries, {0, 1, 1}) == {:not_enough, "", "", {0, 1, 1}, {0, 1, 1}}
    assert consume_until("aaa", boundaries, {0, 1, 1}) == {:not_enough, "", "aaa", {2, 1, 3}, {3, 1, 4}}
  end

  test "consume_until a boundary with more than one character" do
    assert consume_until("aaabbb", "bbb", {0, 1, 1}) == {"bbb", "aaa", {2, 1, 3}, {3, 1, 4}}
    assert consume_until("aaa", "bbb", {0, 1, 1}) == {:not_enough, "", "aaa", {2, 1, 3}, {3, 1, 4}}
  end

  test "consume_until a boundary with escape" do
    assert consume_until("a\\[b[c]", {"[", "\\"}, {0, 1, 1}) == {"[c]", "a[b", {3, 1, 4}, {4, 1, 5}}
    assert consume_until("abc\\[[", {"[", "\\"}, {0, 1, 1}) == {"[", "abc[", {4, 1, 5}, {5, 1, 6}}

    assert consume_until("\\[", {"[", "\\"}, {0, 1, 1}) == {:not_enough, "", "[", {1, 1, 2}, {2, 1, 3}}
    assert consume_until("abc\\[", {"[", "\\"}, {0, 1, 1}) == {:not_enough, "", "abc[", {4, 1, 5}, {5, 1, 6}}
  end

  test "consume_until a boundary with escape keeping the escape" do
    assert consume_until("a\\[b[c]", {"[", "\\"}, {0, 1, 1}, keep_escape: true) == {"[c]", "a\\[b", {3, 1, 4}, {4, 1, 5}}
    assert consume_until("abc\\[[", {"[", "\\"}, {0, 1, 1}, keep_escape: true) == {"[", "abc\\[", {4, 1, 5}, {5, 1, 6}}

    assert consume_until("\\[", {"[", "\\"}, {0, 1, 1}, keep_escape: true) == {:not_enough, "", "\\[", {1, 1, 2}, {2, 1, 3}}
    assert consume_until("abc\\[", {"[", "\\"}, {0, 1, 1}, keep_escape: true) == {:not_enough, "", "abc\\[", {4, 1, 5}, {5, 1, 6}}
  end

  test "consume_until a boundary with escape with more than one character" do
    assert consume_until("a<ESCAPE>[b[c]", {"[", "<ESCAPE>"}, {0, 1, 1}) == {"[c]", "a[b", {10, 1, 11}, {11, 1, 12}}
  end

  test "consume_until a boundary with escape same as boundary" do
    assert consume_until("a##b#c", {"#", "#"}, {0, 1, 1}) == {"#c", "a#b", {3, 1, 4}, {4, 1, 5}}
  end

  test "consume_until multiple boundaries with escape" do
    boundaries = [{"[", "\\"}, {";", "\\"}]

    assert consume_until("a\\[\\;[b]", boundaries, {0, 1, 1}) == {"[b]", "a[;", {4, 1, 5}, {5, 1, 6}}
    assert consume_until("a\\[\\;;b", boundaries, {0, 1, 1}) == {";b", "a[;", {4, 1, 5}, {5, 1, 6}}
    assert consume_until("a\\;\\[[b]", boundaries, {0, 1, 1}) == {"[b]", "a;[", {4, 1, 5}, {5, 1, 6}}
    assert consume_until("a\\;\\[;b", boundaries, {0, 1, 1}) == {";b", "a;[", {4, 1, 5}, {5, 1, 6}}

    assert consume_until("a\\[\\;", boundaries, {0, 1, 1}) == {:not_enough, "", "a[;", {4, 1, 5}, {5, 1, 6}}
    assert consume_until("a\\;\\[", boundaries, {0, 1, 1}) == {:not_enough, "", "a;[", {4, 1, 5}, {5, 1, 6}}
  end

  test "consume_until end of input is a valid boundary" do
    assert consume_until("aaa", "b" , {0, 1, 1}, eof: true) == {"", "aaa", {2, 1, 3}, {3, 1, 4}}
  end

  test "seek" do
    assert seek("aaa", 3, {0, 1, 1}) == {"", "aaa", {2, 1, 3}, {3, 1, 4}}
    assert seek("aaab", 3, {0, 1, 1}) == {"b", "aaa", {2, 1, 3}, {3, 1, 4}}
    assert seek("a\na", 3, {0, 1, 1}) == {"", "a\na", {2, 2, 1}, {3, 2, 2}}
    assert seek("aaa", 4, {0, 1, 1}) == {:not_enough, "", "aaa", {2, 1, 3}, {3, 1, 4}}
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
