defmodule Paco.StreamTest do
  use ExUnit.Case, async: true

  import Paco.Parser

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

    [result] = stream_of("abc") |> Paco.stream(parser) |> Enum.to_list

    assert result == ["ab", "c"]
  end

  test "parse stream of one failure" do
    parser = seq([string("ab"), string("c")])

    [failure] = stream_of("abd") |> Paco.stream(parser) |> Enum.to_list

    assert Paco.Failure.format(failure) ==
      """
      Failed to match seq([string(ab), string(c)]) at 1:1, because it failed to match string(c) at 1:3
      """
  end

  test "parse stream of more successes" do
    parser = seq([string("ab"), string("c")])

    results = stream_of("abcabc") |> Paco.stream(parser) |> Enum.to_list

    assert results == [["ab", "c"], ["ab", "c"]]
  end

  test "parse a success after a failure" do
    parser = seq([string("ab"), string("c")])

    [failure, success] = stream_of("abdabc") |> Paco.stream(parser) |> Enum.to_list

    assert Paco.Failure.format(failure) ==
      """
      Failed to match seq([string(ab), string(c)]) at 1:1, because it failed to match string(c) at 1:3
      """
    assert success == ["ab", "c"]
  end

  test "parse stream when downstream halts the pipe as first command" do
    stream = stream_of("abc")
             |> Stream.each(fn _ -> Process.put(:upstream_called, true) end)
             |> Paco.stream(string("a"))

    downstream_accumulator = make_ref
    result = Enumerable.reduce(stream,
                               {:halt, downstream_accumulator},
                               fn(_, _) ->
                                 Process.put(:downstream_called, true)
                                 {:cont, nil}
                               end)

    assert result == {:halted, downstream_accumulator},
           "the pipeline must halt with the downstream accumulator"
    refute Process.get(:upstream_called, false),
           "upstream must never be called since downstream asked to halt as first command"
    refute Process.get(:downstream_called, false)
           "downstream must never be called since downstream asked to halt as first command"
  end

  test "parse stream when downstream halts" do
    count = fn key, _ -> Process.put(key, Process.get(key, 0) + 1) end

    results = stream_of("abcabc")
             |> Stream.each(&count.(:upstream_called, &1))
             |> Paco.stream(string("abc"))
             # Same problem with Stream.chunk(3) seems that
             # is not related to the paser's stream implementation
             # |> Stream.chunk(3)
             |> Stream.each(&count.(:downstream_called, &1))
             |> Stream.take(1)
             |> Enum.to_list

    assert results == ["abc"]
    assert Process.get(:upstream_called, 0) == 6     # should have been 3???
    assert Process.get(:downstream_called, 0) == 2   # should have been 1???
  end

  test "parse stream when upstream halts" do
    count = fn key, x -> Process.put(key, Process.get(key, 0) + 1) end

    results = stream_of("abcabc")
             |> Stream.each(&count.(:upstream_called, &1))
             |> Stream.take(4)
             |> Paco.stream(string("abc"))
             |> Stream.each(&count.(:downstream_called, &1))
             |> Enum.to_list

    # When the stream is halted from upstream and the parser is waiting
    # for more input we don't return a failure but we truncate the stream.
    # This behaviour is compatibile with Stream.chunk
    assert results == ["abc"]
    assert Process.get(:upstream_called, 0) == 5    # should have been 4???
    assert Process.get(:downstream_called, 0) == 1
  end



  defp stream_of(string) do
    Stream.unfold(string, fn <<h::utf8, t::binary>> -> {<<h>>, t}; <<>> -> nil end)
  end
end
