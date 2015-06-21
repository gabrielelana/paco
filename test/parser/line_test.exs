defmodule Paco.Parser.LineTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse" do
    assert parse(line, "aaa\n") == {:ok, "aaa"}
    assert parse(line, "aaa\n\n") == {:ok, "aaa"}
    assert parse(line, "aaa\r\n") == {:ok, "aaa"}
    assert parse(line, "\n") == {:ok, ""}
  end

  test "the end of input is a valid line terminator" do
    assert parse(line, "aaa") == {:ok, "aaa"}
  end

  test "an empty string is not a line" do
    assert parse(line, "") == {:error, "an empty string is not a line at 1:1"}
  end

  test "escape new lines" do
    assert parse(line(escaped_with: "\\"), "aaa\\\na\n") == {:ok, "aaa\na"}
  end

  test "skip empty lines" do
    success = parse(line(skip_empty: true), "\n", format: :raw)
    assert success.result == ""
    assert success.skip
  end

  test "skip empty lines skips following empty lines" do
    assert parse(line(skip_empty: true), "aaa\n") == {:ok, "aaa"}
    assert parse(line(skip_empty: true), "aaa\n\n") == {:ok, "aaa"}
    assert parse(line(skip_empty: true), "aaa\n\n\n") == {:ok, "aaa"}
  end

  test "skip empty lines skips preceding empty lines" do
    assert parse(line(skip_empty: true), "\naaa\n") == {:ok, "aaa"}
  end

  test "skip empty lines stops at the last newline" do
    success = parse(line(skip_empty: true), "aaa\n\na\n", format: :raw)
    assert success.result == "aaa"
    assert success.tail == [{success.at, "a\n"}]
  end
end
