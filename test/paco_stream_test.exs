defmodule Paco.StreamTest do
  use ExUnit.Case, async: true

  import Paco.Parser
  import Paco.Test.Helper

  test "parser in stream mode will wait for more input" do
    parser = seq([string("ab"), string("c")])
    parser_process = spawn_link(Paco, :parse, [parser, "", [stream: self]])
    assert_receive {^parser_process, :more}

    send(parser_process, {:load, "a"})
    assert_receive {^parser_process, :more}

    send(parser_process, {:load, "b"})
    assert_receive {^parser_process, :more}

    send(parser_process, {:load, "c"})
    assert_receive {^parser_process, {:ok, ["ab", "c"]}}

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

  test "parse stream of one success" do
    parser = seq([string("ab"), string("c")])

    [result] = stream_of("abc")
               |> Paco.stream(parser)
               |> Enum.to_list

    assert result == ["ab", "c"]
  end

  test "parse stream of one failure" do
    parser = seq([string("ab"), string("c")])

    results = stream_of("abd")
              |> Paco.stream(parser)
              |> Enum.to_list

    assert results == []
  end

  test "parse stream of one failure when continue on failure is true" do
    [failure] = stream_of("e")
                |> Paco.stream(string("a"), continue_on_failure: true)
                |> Enum.to_list

    assert Paco.Failure.format(failure) == "Failed to match string(a) at 1:1\n"
  end

  test "parse stream of one failure when raise on failure is true" do
    assert_raise RuntimeError,
                 "Failed to match string(a) at 1:1\n",
                 fn ->
                   stream_of("e")
                   |> Paco.stream(string("a"), raise_on_failure: true)
                   |> Enum.to_list
                 end
  end

  test "Paco.stream!(e, p) is same as Paco.stream(e, p, raise_on_failure: true)" do
    assert_raise RuntimeError,
                 "Failed to match string(a) at 1:1\n",
                 fn ->
                   stream_of("e")
                   |> Paco.stream!(string("a"))
                   |> Enum.to_list
                 end
  end

  test "parse stream of more successes" do
    parser = seq([string("ab"), string("c")])

    results = stream_of("abcabc")
              |> Paco.stream(parser)
              |> Enum.to_list

    assert results == [["ab", "c"], ["ab", "c"]]
  end

  test "parse a success after a failure" do
    parser = seq([string("ab"), string("c")])

    [failure, success] = stream_of("abdabc")
                         |> Paco.stream(parser, continue_on_failure: true)
                         |> Enum.to_list

    assert Paco.Failure.format(failure) ==
      """
      Failed to match seq([string(ab), string(c)]) at 1:1, because it failed to match string(c) at 1:3
      """
    assert success == ["ab", "c"]
  end

  test "parse stream when downstream halts the pipe as first command" do
    stream = stream_of("abc")
             |> Stream.each(&count(:upstream_called, &1))
             |> Paco.stream(string("a"))

    downstream_accumulator = make_ref
    result = Enumerable.reduce(stream,
                               {:halt, downstream_accumulator},
                               fn(_, _) ->
                                 count(:downstream_called)
                                 {:cont, nil}
                               end)

    assert result == {:halted, downstream_accumulator},
           "the pipeline must halt with the downstream accumulator"
    assert Process.get(:upstream_called, 0) == 0,
           "upstream must never be called since downstream asked to halt as first command"
    assert Process.get(:downstream_called, 0) == 0,
           "downstream must never be called since downstream asked to halt as first command"
  end

  test "parse stream when downstream suspend the pipe as first command" do
    stream = stream_of("abc")
             |> Stream.each(&count(:upstream_called, &1))
             |> Paco.stream(string("a"))

    downstream_accumulator = make_ref
    result = Enumerable.reduce(stream,
                               {:suspend, downstream_accumulator},
                               fn(_, _) ->
                                 count(:downstream_called)
                                 {:cont, nil}
                               end)

    assert {:suspended, ^downstream_accumulator, continuation} = result,
           "the pipeline must suspend with the downstream accumulator and a continuation"
    assert Process.get(:upstream_called, 0) == 0,
           "upstream must never be called since downstream asked to suspend as first command"
    assert Process.get(:downstream_called, 0) == 0,
           "downstream must never be called since downstream asked to suspend as first command"

    assert is_function(continuation, 1)
  end

  test "parse stream when downstream halts" do
    results = stream_of("abcabc")
             |> Stream.each(&count(:upstream_called, &1))
             |> Paco.stream(string("abc"))
             |> Stream.each(&count(:downstream_called, &1))
             |> Stream.take(1)
             |> Enum.to_list

    assert results == ["abc"]
    assert Process.get(:upstream_called, 0) == 6     # should have been 3???
    assert Process.get(:downstream_called, 0) == 2   # should have been 1???
  end

  test "parse stream when upstream halts" do
    results = stream_of("abcabc")
             |> Stream.each(&count(:upstream_called, &1))
             |> Stream.take(4)
             |> Paco.stream(string("abc"))
             |> Stream.each(&count(:downstream_called, &1))
             |> Enum.to_list

    # When the stream is halted from upstream and the parser is waiting
    # for more input we don't return a failure but we truncate the stream.
    # This behaviour is compatibile with Stream.chunk
    assert results == ["abc"]
    assert counted(:upstream_called) == 5    # should have been 4???
    assert counted(:downstream_called) == 1
  end



  defp count(key), do: count(key, nil)
  defp count(key, _) do
    Process.put(key, Process.get(key, 0) + 1)
  end

  defp counted(key), do: Process.get(key, 0)
end
