defmodule Paco.Parser.LineTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse" do
    assert parse(line, "aaa\n") == {:ok, [{{0, 1, 1}, "aaa"}]}
    assert parse(line, "aaa\n\n") == {:ok, [{{0, 1, 1}, "aaa"}]}
    assert parse(line, "aaa\r\n") == {:ok, [{{0, 1, 1}, "aaa"}]}
    assert parse(line, "\n") == {:ok, [{{0, 1, 1}, ""}]}
  end

  test "the end of input is a valid line terminator" do
    assert parse(line, "aaa") == {:ok, [{{0, 1, 1}, "aaa"}]}
  end

  test "an empty string is not a line" do
    assert parse(line, "") == {:error, "an empty string is not a line at 1:1"}
  end

  test "escape new lines" do
    assert parse(line(escaped_with: "\\"), "aaa\\\na\n") == {:ok, [{{0, 1, 1}, "aaa\na"}]}
  end

  test "skip empty lines" do
    success = parse(line(skip_empty: true), "\n", format: :raw)
    assert success.result == [{{1, 2, 1}, ""}]
    assert success.skip
  end

  test "skip empty lines skips following empty lines" do
    assert parse(line(skip_empty: true), "aaa\n") == {:ok, [{{0, 1, 1}, "aaa"}]}
    assert parse(line(skip_empty: true), "aaa\n\n") == {:ok, [{{0, 1, 1}, "aaa"}]}
    assert parse(line(skip_empty: true), "aaa\n\n\n") == {:ok, [{{0, 1, 1}, "aaa"}]}
  end

  test "skip empty lines skips preceding empty lines" do
    assert parse(line(skip_empty: true), "\naaa\n") == {:ok, [{{1, 2, 1}, "aaa"}]}
  end

  test "skip empty lines stops at the last newline" do
    success = parse(line(skip_empty: true), "aaa\n\na\n", format: :raw)
    assert success.result == [{{0, 1, 1}, "aaa"}]
    assert success.tail == [{success.at, "a\n"}]
  end
end
