defmodule Paco.ParserModuleTest do
  use ExUnit.Case, async: true

  import Paco.Parser

  defmodule UsePacoLastParserIsTheRoot do
    use Paco

    parser aaa, do: lit("aaa")
    parser bbb, do: lit("bbb")
  end

  test "use paco, last parser is the root" do
    assert UsePacoLastParserIsTheRoot.parse("bbb") == {:ok, "bbb"}
  end


  defmodule UsePacoMarkRootWithRootMacro do
    use Paco

    root aaa
    parser aaa, do: lit("aaa")
    parser bbb, do: lit("bbb")
  end

  test "use paco, mark root with root macro" do
    assert UsePacoMarkRootWithRootMacro.parse("aaa") == {:ok, "aaa"}
  end


  defmodule UsePacoMarkRootWithRootMacroInline do
    use Paco

    root parser aaa, do: lit("aaa")
    parser bbb, do: lit("bbb")
  end

  test "use paco, mark root with root macro inline" do
    assert UsePacoMarkRootWithRootMacroInline.parse("aaa") == {:ok, "aaa"}
  end


  defmodule UsePacoReferenceOtherParsers do
    use Paco

    root parser all, do: sequence_of([aaa, bbb])
    parser aaa, do: lit("aaa")
    parser bbb, do: lit("bbb")
  end

  test "use paco, reference other parsers" do
    assert UsePacoReferenceOtherParsers.parse("aaabbb") == {:ok, ["aaa", "bbb"]}
  end

  test "failures keeps the parsers name" do
    assert UsePacoReferenceOtherParsers.parse("aaaccc") == {:error,
      ~s|expected "bbb" (bbb < all) at 1:4 but got "ccc"|
    }
  end
end
