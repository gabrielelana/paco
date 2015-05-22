defmodule Paco.StreamTest do
  use ExUnit.Case, async: true

  import Paco.Parser
  import Paco.Test.Helper

  test "parser in stream mode will wait for more data" do
    stream = self
    parser = sequence_of([lit("ab"), lit("c")])
    parser_process = spawn_link(
      fn ->
        send(stream, {self, Paco.parse(parser, "", [stream: stream])})
      end
    )
    assert_receive {^parser_process, :more}

    send(parser_process, {:load, "a"})
    assert_receive {^parser_process, :more}

    send(parser_process, {:load, "b"})
    assert_receive {^parser_process, :more}

    send(parser_process, {:load, "c"})
    assert_receive {^parser_process, {:ok, ["ab", "c"]}}

    refute Process.alive?(parser_process)
  end

  test "parser in stream mode can be stopped when waiting for more data" do
    stream = self
    parser = sequence_of([lit("a"), lit("b")])
    parser_process = spawn_link(
      fn ->
        send(stream, {self, Paco.parse(parser, "", [stream: stream])})
      end
    )
    assert_receive {^parser_process, :more}

    send(parser_process, {:load, "a"})
    assert_receive {^parser_process, :more}

    send(parser_process, :halted)
    assert_receive {^parser_process, {:error,
      """
      Failed to match sequence_of#3([lit#1, lit#2]) at 1:1, because it failed to match lit#2("b") at 1:2
      """
    }}

    refute Process.alive?(parser_process)
  end

  test "parse stream of one success" do
    parser = sequence_of([lit("ab"), lit("c")])

    [result] = stream_of("abc")
               |> Paco.Stream.parse(parser)
               |> Enum.to_list

    assert result == ["ab", "c"]
  end

  test "parse stream of one success with tagged format" do
    parser = sequence_of([lit("ab"), lit("c")])

    [result] = stream_of("abc")
               |> Paco.Stream.parse(parser, format: :tagged)
               |> Enum.to_list

    assert result == {:ok, ["ab", "c"]}
  end

  test "parse stream of one success with raw format" do
    parser = sequence_of([lit("ab"), lit("c")])

    [result] = stream_of("abc")
               |> Paco.Stream.parse(parser, format: :raw)
               |> Enum.to_list

    assert %Paco.Success{} = result
  end

  test "parse stream of one failure" do
    parser = sequence_of([lit("ab"), lit("c")])

    results = stream_of("abd")
              |> Paco.Stream.parse(parser)
              |> Enum.to_list

    assert results == []
  end

  test "parse stream of one failure with yield on failure and tagged format (default)" do
    [failure] = stream_of("e")
                |> Paco.Stream.parse(lit("a"), on_failure: :yield)
                |> Enum.to_list

    assert failure == {:error,
      """
      Failed to match lit#1("a") at 1:1
      """
    }
  end

  test "parse stream of one failure with raise on failure" do
    assert_raise Paco.Failure,
                 """
                 Failed to match lit#1("a") at 1:1
                 """,
                 fn ->
                   stream_of("e")
                   |> Paco.Stream.parse(lit("a"), on_failure: :raise)
                   |> Enum.to_list
                 end
  end

  test "Paco.Stream.parse!(e, p) is same as Paco.Stream.parse(e, p, on_failure: :raise)" do
    assert_raise Paco.Failure,
                 """
                 Failed to match lit#1("a") at 1:1
                 """,
                 fn ->
                   stream_of("e")
                   |> Paco.Stream.parse!(lit("a"))
                   |> Enum.to_list
                 end
  end

  test "parse stream of more successes" do
    parser = sequence_of([lit("ab"), lit("c")])

    results = stream_of("abcabc")
              |> Paco.Stream.parse(parser)
              |> Enum.to_list

    assert results == [["ab", "c"], ["ab", "c"]]
  end

  test "parse stream of more successes with tagged format option" do
    parser = sequence_of([lit("ab"), lit("c")])

    results = stream_of("abcabc")
              |> Paco.Stream.parse(parser, format: :tagged)
              |> Enum.to_list

    assert results == [{:ok, ["ab", "c"]}, {:ok, ["ab", "c"]}]
  end

  test "parse stream when downstream halts the pipe as first command" do
    stream = stream_of("abc")
             |> Stream.each(&count(:upstream_called, &1))
             |> Paco.Stream.parse(lit("a"))

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
             |> Paco.Stream.parse(lit("a"))

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
             |> Paco.Stream.parse(lit("abc"))
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
             |> Paco.Stream.parse(lit("abc"))
             |> Stream.each(&count(:downstream_called, &1))
             |> Enum.to_list

    # When the stream is halted from upstream and the parser is waiting
    # for more data we don't return a failure but we truncate the stream.
    # This behaviour is compatibile with Stream.chunk
    assert results == ["abc"]
    assert counted(:upstream_called) == 5    # should have been 4???
    assert counted(:downstream_called) == 1
  end

  test "for successes, no matter how input is partitioned, the result must be always the same" do
    partitions = [
      ["a", "a", "a", "a"],
      ["aa", "a", "a"],
      ["a", "aa", "a"],
      ["a", "a", "aa"],
      ["aa", "aa"],
      ["aaa", "a"],
      ["a", "aaa"],
      ["aaaa"]]

    for partition <- partitions do
      result = partition
               |> Paco.Stream.parse(lit("aa"))
               |> Enum.to_list

      assert result == ["aa", "aa"]
      assert Process.info(self, :messages) == {:messages, []}
    end
  end

  test "for failures, no matter how input is partitioned, the result must be always the same" do
    partitions = [
      ["a", "a", "b", "b"],
      ["aa", "b", "b"],
      ["a", "ab", "b"],
      ["a", "a", "bb"],
      ["aa", "bb"],
      ["aab", "b"],
      ["a", "abb"],
      ["aabb"]]

    parser = lit("aa")

    for partition <- partitions do
      result = partition
               |> Paco.Stream.parse(parser)
               |> Enum.to_list

      assert result == ["aa"]
      assert Process.info(self, :messages) == {:messages, []}
    end
  end

  test "partial match at the end of the stream" do
    parser = lit("aa")

    result = ["aaa"]
             |> Paco.Stream.parse(parser)
             |> Enum.to_list

    assert result == ["aa"]
    assert Process.info(self, :messages) == {:messages, []}
  end

  test "a parser in stream mode that don't consume any input will fail" do
    parser = lit("")

    result = ["aaa"]
             |> Paco.Stream.parse(parser)
             |> Enum.to_list
    assert result == []

    result = [""]
             |> Paco.Stream.parse(parser)
             |> Enum.to_list
    assert result == []

    result = ["aaa"]
             |> Paco.Stream.parse(parser, on_failure: :yield)
             |> Enum.to_list
    assert result == [{:error,
      """
      Failed to match lit#1("") at 1:1, because it didn't consume any input
      """
    }]
  end

  test "empty chunks in stream don't change the result" do
    result = ["", "a", "", "a", ""]
             |> Paco.Stream.parse(lit("aa"))
             |> Enum.to_list

    assert result == ["aa"]
  end

  test "stream always ends with a failure" do
    result = ["aa"]
             |> Paco.Stream.parse(lit("aa"), on_failure: :yield)
             |> Enum.to_list

    # The parser process after a success restarts the parser on what
    # it's left of input, it doesn't know if the stream it's done or halted.
    # Since the parser is already started and a parser could return only one
    # of %Paco.Success or %Paco.Failure a %Paco.Failure is returned without
    # introducing a special value or other hacks
    assert result == [{:ok, "aa"}, {:error,
      """
      Failed to match lit#1("aa") at 1:3
      """
    }]
  end
end
