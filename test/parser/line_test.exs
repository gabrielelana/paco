defmodule Paco.Parser.LineTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "parse something that must be contained in a line" do
    assert parse("aaa\n", line(lit("aaa"))) == {:ok, "aaa"}
    assert parse("aaa\r\n", line(lit("aaa"))) == {:ok, "aaa"}
    assert parse("\n", line(empty)) == {:ok, ""}
  end

  test "the end of input is a valid line terminator" do
    assert parse("aaa", line(lit("aaa"))) == {:ok, "aaa"}
  end

  test "the line content must be completely specified" do
    assert parse("aaa\n", line(lit("a"))) == {:error,
      ~s|expected end of line at 1:2 but got "aa"|
    }
  end

  test "does not consumes following empty lines" do
    parser = line(lit("aaa"))
    assert %Paco.Success{tail: ""} = parse("aaa\n", parser, format: :raw)
    assert %Paco.Success{tail: "\n"} = parse("aaa\n\n", parser, format: :raw)
    assert %Paco.Success{tail: "\n\n"} = parse("aaa\n\n\n", parser, format: :raw)
  end

  test "does not consumes preceding empty lines" do
    assert parse("\naaa", line(lit("aaa"))) == {:error,
      ~s|expected "aaa" at 1:1 but got "\naa"|
    }
  end

  test "consumes and skips following empty lines when skip_empty" do
    parser = line(lit("aaa"), skip_empty: true)
    assert %Paco.Success{tail: ""} = parse("aaa\n", parser, format: :raw)
    assert %Paco.Success{tail: ""} = parse("aaa\n\n", parser, format: :raw)
    assert %Paco.Success{tail: ""} = parse("aaa\n\n\n", parser, format: :raw)
  end

  test "consumes and skips preceding empty lines when skip_empty" do
    parser = line(lit("aaa"), skip_empty: true)
    assert parse("\naaa", parser) == {:ok, "aaa"}
    assert parse("\n\naaa", parser) == {:ok, "aaa"}
    assert parse("\n\n\naaa", parser) == {:ok, "aaa"}
  end

  test "does not consumes and skips following non empty lines when skip empty" do
    parser = line(lit("aaa"), skip_empty: true)
    assert %Paco.Success{tail: "a\n"} = parse("aaa\n\na\n", parser, format: :raw)
  end

  test "keeps skipped what the inner parser skips at the beginning" do
    parser = line(lit("aaa") |> preceded_by("b"))
    assert %Paco.Success{from: {1, 1, 2}} = parse("baaa", parser, format: :raw)
  end

  test "must at least consume a newline" do
    # This will be replaced by the infinite recursion check, for now we need this
    assert parse("", line("")) == {:error,
      ~s|expected at least an empty line at 1:1|
    }
  end
end
