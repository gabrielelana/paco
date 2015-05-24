defmodule Paco.Parser.SurroundedByTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "success" do
    assert parse(surrounded_by(lit("a"), lit("["), lit("]")), "[a]") == {:ok, "a"}
    assert parse(surrounded_by(lit("a"), lit("*")), "*a*") == {:ok, "a"}
  end

  test "describe" do
    assert describe(surrounded_by(lit("a"), lit("["), lit("]"))) ==
      ~s|surrounded_by(lit("a"), lit("["), lit("]"))|
  end

  test "failure because of surrounded parser" do
    assert parse(surrounded_by(lit("a"), lit("["), lit("]")), "[b]") == {:error,
      """
      Failed to match surrounded_by(lit("a"), lit("["), lit("]")) at 1:1, \
      because it failed to match lit("a") at 1:2
      """
    }
  end

  test "failure because of left parser" do
    assert parse(surrounded_by(lit("a"), lit("["), lit("]")), "*a]") == {:error,
      """
      Failed to match surrounded_by(lit("a"), lit("["), lit("]")) at 1:1, \
      because it failed to match lit("[") at 1:1
      """
    }
  end

  test "failure because of right parser" do
    assert parse(surrounded_by(lit("a"), lit("["), lit("]")), "[a*") == {:error,
      """
      Failed to match surrounded_by(lit("a"), lit("["), lit("]")) at 1:1, \
      because it failed to match lit("]") at 1:3
      """
    }
  end

  test "notify events on success" do
    parser = lit("a") |> surrounded_by(lit("["), lit("]"))
    Helper.assert_events_notified(parser, "[a]", [
      {:started, ~s|surrounded_by(lit("a"), lit("["), lit("]"))|},
      {:started, ~s|lit("a")|},
      {:matched, {1, 1, 2}, {1, 1, 2}, {2, 1, 3}},
      {:matched, {0, 1, 1}, {2, 1, 3}, {3, 1, 4}}
    ])
  end

  test "notify events on failure" do
    parser = lit("a") |> surrounded_by(lit("["), lit("]"))
    Helper.assert_events_notified(parser, "[b]", [
      {:started, ~s|surrounded_by(lit("a"), lit("["), lit("]"))|},
      {:started, ~s|lit("a")|},
      {:failed, {1, 1, 2}},
      {:failed, {0, 1, 1}}
    ])
  end
end
