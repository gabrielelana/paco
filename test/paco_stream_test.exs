defmodule Paco.StreamTest do
  use ExUnit.Case, async: true

  import Paco.Parser

  test "parser in stream mode will wait for more input" do
    parser = seq([string("a"), string("b"), string("c")])
    parser_process = spawn_link(Paco, :parse, [parser, "", [stream: self]])
    assert_receive {^parser_process, :more}

    send(parser_process, {:load, "a"})
    assert_receive {^parser_process, :more}

    send(parser_process, {:load, "b"})
    assert_receive {^parser_process, :more}

    send(parser_process, {:load, "c"})
    assert_receive {^parser_process, {:ok, ["a", "b", "c"]}}

    refute Process.alive?(parser_process)
  end

  test "parser in stream mode can be stopped when waiting for more input" do
    parser = seq([string("a"), string("b")])
    parser_process = spawn_link(Paco, :parse, [parser, "", [stream: self]])
    assert_receive {^parser_process, :more}

    send(parser_process, {:load, "a"})
    assert_receive {^parser_process, :more}

    send(parser_process, :halt)
    assert_receive {^parser_process, {:error, failure}}

    refute Process.alive?(parser_process)

    assert Paco.Failure.format(failure) ==
      """
      Failed to match seq([string(a), string(b)]) at 1:1, because it failed to match string(b) at 1:2
      """
  end
end
