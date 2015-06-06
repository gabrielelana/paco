defmodule Paco.Parser.UntilTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser
  import Paco.String, only: [uppercase?: 1]

  alias Paco.Test.Helper

  test "parse until string boundary" do
    assert parse(until("c"), "abc") == {:ok, "ab"}
    assert parse(until("c"), "abcb") == {:ok, "ab"}
  end

  test "parse until string boundary with escape" do
    assert parse(until("c", escaped_with: "\\"), "ab\\cdce") == {:ok, "ab\\cd"}
  end

  test "parse until a function boundary" do
    assert parse(until(&uppercase?/1), "abC") == {:ok, "ab"}
  end

  test "failure when missing string boundary" do
    assert parse(until("c"), "aaa") == {:error,
      ~s|expected something ended by "c" at 1:1 but got "aaa"|
    }
  end

  test "failure when missing string boundary with escape" do
    assert parse(until("c", escaped_with: "\\"), "a\\ca") == {:error,
      ~S|expected something ended by "c" at 1:1 but got "a\ca"|
    }
  end

  test "failure when missing function boundary" do
    assert parse(until(&uppercase?/1), "abc") == {:error,
      ~s|expected something ended by a character which satisfy uppercase? at 1:1 but got "abc"|
    }
  end

  test "failure with description" do
    parser = until("c") |> as("TOKEN")
    assert parse(parser, "aaa") == {:error,
      ~s|expected something ended by "c" (TOKEN) at 1:1 but got "aaa"|
    }
  end

  test "stream mode until a boundary" do
    for stream <- Helper.streams_of("aab") do
      result = stream
               |> Paco.Stream.parse(until("b"))
               |> Enum.to_list

      assert result == ["aa"]
    end
  end

  test "stream mode until a boundary with escape" do
    for stream <- Helper.streams_of("a\\bab") do
      result = stream
               |> Paco.Stream.parse(until("b", escaped_with: "\\"))
               |> Enum.to_list

      assert result == ["a\\ba"]
    end
  end

  test "stream mode when missing boundary" do
    for stream <- Helper.streams_of("aa") do
      result = stream
               |> Paco.Stream.parse(until("b"))
               |> Enum.to_list

      assert result == []
    end
  end

  test "stream mode for an empty input" do
    result = [""]
             |> Paco.Stream.parse(until("b"))
             |> Enum.to_list

    assert result == []
  end
end
