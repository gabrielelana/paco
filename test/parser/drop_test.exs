defmodule Paco.Parser.DropTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "drop" do
    assert parse(drop(lit("a")), "aaa") == {:ok, [{{0, 1, 1}, "a", :drop},
                                                  {{1, 1, 2}, "aa"}]}
    assert parse(drop(lit("aa")), "aaa") == {:ok, [{{0, 1, 1}, "aa", :drop},
                                                   {{2, 1, 3}, "a"}]}
    assert parse(drop(lit("aaa")), "aaa") == {:ok, [{{0, 1, 1}, "aaa", :drop}]}
  end

  test "drop within a region" do
    parser = drop(lit("a")) |> within(lit("aaa"))
    assert parse(parser, "aaa") == {:ok, [{{0, 1, 1}, "a", :drop},
                                          {{1, 1, 2}, "aa"}]}

    parser = lit("aaa") |> drop("a")
    assert parse(parser, "aaa") == {:ok, [{{0, 1, 1}, "a", :drop},
                                          {{1, 1, 2}, "aa"}]}
  end

  test "keeps the input when it fails" do
    assert parse(drop(lit("b")), "aaa") == {:ok, [{{0, 1, 1}, "aaa"}]}
  end

  test "doesn't drop skipped results" do
    assert parse(drop(skip(lit("a"))), "aaa") == {:ok, [{{0, 1, 1}, "aaa"}]}
  end
end
