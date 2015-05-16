defmodule Paco.Parser.SurroundedByTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "success" do
    assert parse(surrounded_by(literal("a"), literal("["), literal("]")), "[a]") == {:ok, "a"}
    assert parse(surrounded_by(literal("a"), literal("*")), "*a*") == {:ok, "a"}
  end

  test "describe" do
    assert describe(surrounded_by(literal("a"), literal("["), literal("]"))) ==
      "surrounded_by#4(literal#1, literal#2, literal#3)"
  end

  test "failure because of surrounded parser" do
    assert parse(surrounded_by(literal("a"), literal("["), literal("]")), "[b]") == {:error,
      """
      Failed to match surrounded_by#4(literal#1, literal#2, literal#3) at 1:1, because it failed to match literal#1("a") at 1:2
      """
    }
  end

  test "failure because of left parser" do
    assert parse(surrounded_by(literal("a"), literal("["), literal("]")), "*a]") == {:error,
      """
      Failed to match surrounded_by#4(literal#1, literal#2, literal#3) at 1:1, because it failed to match literal#2("[") at 1:1
      """
    }
  end

  test "failure because of right parser" do
    assert parse(surrounded_by(literal("a"), literal("["), literal("]")), "[a*") == {:error,
      """
      Failed to match surrounded_by#4(literal#1, literal#2, literal#3) at 1:1, because it failed to match literal#3("]") at 1:3
      """
    }
  end

  test "notify events on success" do
    parser = literal("a") |> surrounded_by(literal("["), literal("]"))
    assert Helper.events_notified_by(parser, "[a]") == [
      {:loaded, "[a]"},
      {:started, "surrounded_by#4(literal#1, literal#2, literal#3)"},
      {:started, "sequence_of#7([skip#5, literal#1, skip#6])"},
      {:started, ~s|literal#2("[")|},
      {:matched, {0, 1, 1}, {0, 1, 1}, {1, 1, 2}},
      {:started, ~s|literal#1("a")|},
      {:matched, {1, 1, 2}, {1, 1, 2}, {2, 1, 3}},
      {:started, ~s|literal#3("]")|},
      {:matched, {2, 1, 3}, {2, 1, 3}, {3, 1, 4}},
      {:matched, {0, 1, 1}, {2, 1, 3}, {3, 1, 4}},
      {:matched, {0, 1, 1}, {2, 1, 3}, {3, 1, 4}}]
  end

  test "notify events on failure" do
    parser = literal("a") |> surrounded_by(literal("["), literal("]"))
    assert Helper.events_notified_by(parser, "[b]") == [
      {:loaded, "[b]"},
      {:started, "surrounded_by#4(literal#1, literal#2, literal#3)"},
      {:started, "sequence_of#7([skip#5, literal#1, skip#6])"},
      {:started, ~s|literal#2("[")|},
      {:matched, {0, 1, 1}, {0, 1, 1}, {1, 1, 2}},
      {:started, ~s|literal#1("a")|},
      {:failed, {1, 1, 2}},
      {:failed, {0, 1, 1}},
      {:failed, {0, 1, 1}}]
  end
end
