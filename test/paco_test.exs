defmodule Paco.Test do
  use ExUnit.Case

  import Paco.Parser

  defmodule SomethingToParse do
    use Paco

    # root aaa
    root parser aaa, do: string("aaa")
    parser bbb, do: string("bbb")
  end

  test "use macro" do
    assert SomethingToParse.parse("aaa") == {:ok, "aaa"}
  end

end
