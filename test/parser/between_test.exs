defmodule Paco.Parser.BetweenTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "between two delimiters" do
    assert parse(between("<", ">"), "<a>") == {:ok, "a"}
  end

  test "between two delimiters given as tuple" do
    assert parse(between({"<", ">"}), "<a>") == {:ok, "a"}
  end

  test "between the same delimiter" do
    assert parse(between("@"), "@a@") == {:ok, "a"}
  end

  test "delimiters can be escaped" do
    assert parse(between("<", ">", escaped_with: "\\"), "<a\\>a>") == {:ok, "a>a"}
    assert parse(between({"<", ">"}, escaped_with: "\\"), "<a\\>a>") == {:ok, "a>a"}
    assert parse(between("@", escaped_with: "\\"), "@a\\@a@") == {:ok, "a@a"}
  end

  test "consumes surrounding whitespaces and strips the content" do
    assert parse(between("<", ">"), " <a>") == {:ok, "a"}
    assert parse(between("<", ">"), "< a>") == {:ok, "a"}
    assert parse(between("<", ">"), "<a >") == {:ok, "a"}
    assert parse(between("<", ">"), "<a> ") == {:ok, "a"}
  end

  test "doesn't strip the content" do
    assert parse(between("<", ">", strip: false), "< a>") == {:ok, " a"}
    assert parse(between("<", ">", strip: false), "<a >") == {:ok, "a "}
  end

  test "fails when left delimiter is missing" do
    assert parse(between("<", ">"), "a") == {:error,
      ~s|expected "<" at 1:1 but got "a"|
    }
  end

  test "fails when right delimiter is missing" do
    assert parse(between("<", ">"), "<aaaa") == {:error,
      ~s|expected ">" at 1:6 but got the end of input|
    }
  end
end
