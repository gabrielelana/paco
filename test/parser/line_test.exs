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

  test "refine the line" do
    assert parse(line(lit("a") |> followed_by(rol)), "aaa\n") == {:ok, "a"}

    assert parse(line(lit("a")), "aaa\n") == {:error,
      ~s|expected end of line at 1:2 but got "aa"|
    }
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
    assert %Paco.Success{tail: ""} = parse(line(skip_empty: true), "aaa\n", format: :raw)
    assert %Paco.Success{tail: ""} = parse(line(skip_empty: true), "aaa\n\n", format: :raw)
    assert %Paco.Success{tail: ""} = parse(line(skip_empty: true), "aaa\n\n\n", format: :raw)

    assert %Paco.Success{tail: ""} = parse(line, "aaa\n", format: :raw)
    assert %Paco.Success{tail: "\n"} = parse(line, "aaa\n\n", format: :raw)
    assert %Paco.Success{tail: "\n\n"} = parse(line, "aaa\n\n\n", format: :raw)
  end

  test "skip empty lines skips preceding empty lines" do
    assert parse(line(skip_empty: true), "\naaa") == {:ok, "aaa"}
    assert parse(line(skip_empty: true), "\n\naaa") == {:ok, "aaa"}
    assert parse(line(skip_empty: true), "\n\n\naaa") == {:ok, "aaa"}

    assert parse(line, "\naaa") == {:ok, ""}
    assert parse(many(line), "\naaa") == {:ok, ["", "aaa"]}
  end

  test "skip empty lines stops at the last newline" do
    success = parse(line(skip_empty: true), "aaa\n\na\n", format: :raw)
    assert success.result == "aaa"
    assert success.tail == "a\n"
  end
end
