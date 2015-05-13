defmodule PacoTest do
  use ExUnit.Case, async: true

  import Paco.Parser

  defmodule UsePacoLastParserIsTheRoot do
    use Paco

    parser aaa, do: literal("aaa")
    parser bbb, do: literal("bbb")
  end

  test "use paco, last parser is the root" do
    assert UsePacoLastParserIsTheRoot.parse("bbb") == {:ok, "bbb"}
  end


  defmodule UsePacoMarkRootWithRootMacro do
    use Paco

    root aaa
    parser aaa, do: literal("aaa")
    parser bbb, do: literal("bbb")
  end

  test "use paco, mark root with root macro" do
    assert UsePacoMarkRootWithRootMacro.parse("aaa") == {:ok, "aaa"}
  end


  defmodule UsePacoMarkRootWithRootMacroInline do
    use Paco

    root parser aaa, do: literal("aaa")
    parser bbb, do: literal("bbb")
  end

  test "use paco, mark root with root macro inline" do
    assert UsePacoMarkRootWithRootMacroInline.parse("aaa") == {:ok, "aaa"}
  end


  defmodule UsePacoReferenceOtherParsers do
    use Paco

    root parser all, do: sequence_of([aaa, bbb])
    parser aaa, do: literal("aaa")
    parser bbb, do: literal("bbb")
  end

  test "describe" do
    assert Paco.describe(UsePacoReferenceOtherParsers.all) == "all"
    assert Paco.describe(UsePacoReferenceOtherParsers.aaa) == "aaa"
    assert Paco.describe(UsePacoReferenceOtherParsers.bbb) == "bbb"
  end

  test "use paco, reference other parsers" do
    assert UsePacoReferenceOtherParsers.parse("aaabbb") == {:ok, ["aaa", "bbb"]}
  end

  test "failures keeps the parsers name" do
    assert UsePacoReferenceOtherParsers.parse("aaaccc") == {:error,
      """
      Failed to match all at 1:1, because it failed to match bbb at 1:4
      """
    }
  end
end
