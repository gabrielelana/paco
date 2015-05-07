defmodule Paco.StreamTest do
  use ExUnit.Case, async: true

  import Paco.Parser

  test "parser in stream mode will wait for more input" do
    parser = seq([string("a"), string("b"), string("c")])
    parser_process = spawn_link(Paco, :parse, [parser, "a", [stream: self]])
    assert_receive {^parser_process, :more}
    send(parser_process, {:load, "b"})
    assert_receive {^parser_process, :more}
    send(parser_process, {:load, "c"})
    assert_receive {^parser_process, {:ok, ["a", "b", "c"]}}
    refute Process.alive?(parser_process)
  end
end
