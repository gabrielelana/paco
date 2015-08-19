defmodule Paco.Parser.BetweenTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "between two delimiters" do
    assert parse("<a>", between("<", ">")) == {:ok, "a"}
  end

  test "between two delimiters given as tuple" do
    assert parse("<a>", between({"<", ">"})) == {:ok, "a"}
    assert parse("<a>", between(Paco.ASCII.angle_brackets)) == {:ok, "a"}
  end

  test "between the same delimiter" do
    assert parse("@a@", between("@")) == {:ok, "a"}
  end

  test "delimiters can be escaped" do
    assert parse("<a\\>a>", between("<", ">", escaped_with: "\\")) == {:ok, "a>a"}
    assert parse("<a\\>a>", between({"<", ">"}, escaped_with: "\\")) == {:ok, "a>a"}
    assert parse("@a\\@a@", between("@", escaped_with: "\\")) == {:ok, "a@a"}
  end

  test "consumes surrounding whitespaces and strips the content" do
    assert parse(" <a>", between("<", ">")) == {:ok, "a"}
    assert parse("< a>", between("<", ">")) == {:ok, "a"}
    assert parse("<a >", between("<", ">")) == {:ok, "a"}
    assert parse("<a> ", between("<", ">")) == {:ok, "a"}
  end

  test "doesn't strip the content" do
    assert parse("< a>", between("<", ">", strip: false)) == {:ok, " a"}
    assert parse("<a >", between("<", ">", strip: false)) == {:ok, "a "}
  end

  test "fails when left delimiter is missing" do
    assert parse("a", between("<", ">")) == {:error,
      ~s|expected "<" at 1:1 but got "a"|
    }
  end

  test "fails when right delimiter is missing" do
    assert parse("<aaaa", between("<", ">")) == {:error,
      ~s|expected ">" at 1:6 but got the end of input|
    }
  end

  test "quoted_by" do
    assert parse(~s|"a"|, quoted_by(~s|"|)) == {:ok, "a"}
    assert parse(~s|"a"|, quoted_by([~s|"|, ~s|'|])) == {:ok, "a"}
    assert parse(~s|'a'|, quoted_by([~s|"|, ~s|'|])) == {:ok, "a"}
    assert parse(~s|'a'|, quoted_by(Paco.ASCII.single_quote)) == {:ok, "a"}
    assert parse(~s|"a"|, quoted_by(Paco.ASCII.double_quote)) == {:ok, "a"}
    assert parse(~s|'a'|, quoted_by(Paco.ASCII.quotes)) == {:ok, "a"}
    assert parse(~s|"a"|, quoted_by(Paco.ASCII.quotes)) == {:ok, "a"}
  end
end
