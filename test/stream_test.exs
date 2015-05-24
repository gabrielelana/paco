defmodule Paco.StreamTest do
  use ExUnit.Case, async: true

  import Paco.Parser
  alias Paco.Test.Helper

  test "parse" do
    for stream <- Helper.streams_of("ab") do
      result = stream
               |> Paco.Stream.parse(lit("ab"))
               |> Enum.to_list

      assert result == ["ab"]
    end
  end

  test "parse with more than one success" do
    for stream <- Helper.streams_of("abab") do
      result = stream
               |> Paco.Stream.parse(lit("ab"))
               |> Enum.to_list

      assert result == ["ab", "ab"]
    end
  end

  test "parse with tagged format" do
    for stream <- Helper.streams_of("ab") do
      result = stream
               |> Paco.Stream.parse(lit("ab"), format: :tagged)
               |> Enum.to_list

      assert result == [{:ok, "ab"}]
    end
  end

  test "parse with raw format" do
    for stream <- Helper.streams_of("ab") do
      result = stream
               |> Paco.Stream.parse(lit("ab"), format: :raw)
               |> Enum.to_list

      assert [%Paco.Success{}] = result
    end
  end

  test "parse failure" do
    for stream <- Helper.streams_of("abac") do
      result = stream
               |> Paco.Stream.parse(lit("ab"))
               |> Enum.to_list

      assert result == ["ab"]
    end
  end

  test "parse failure with yield on failure" do
    parser = lit("ab")

    for stream <- Helper.streams_of("abac") do
      result = stream
               |> Paco.Stream.parse(parser, on_failure: :yield)
               |> Enum.to_list

      # The format is automatically set to :tagged otherwise would
      # be impossibile to differentiate between an error string and
      # a string result of a successful parser
      assert result == [{:ok, "ab"}, {:error,
        """
        Failed to match lit("ab") at 1:3
        """
      }]
    end
  end

  test "parse failure with raise on failure" do
    parser = lit("a")

    for stream <- Helper.streams_of("e") do
      assert_raise Paco.Failure,
                   """
                   Failed to match lit("a") at 1:1
                   """,
                   fn ->
                     stream
                     |> Paco.Stream.parse(parser, on_failure: :raise)
                     |> Enum.to_list
                   end
    end
  end

  test "Paco.Stream.parse!(s, p) is same as Paco.Stream.parse(e, p, on_failure: :raise)" do
    parser = lit("a")

    for stream <- Helper.streams_of("e") do
      assert_raise Paco.Failure,
                   """
                   Failed to match lit("a") at 1:1
                   """,
                   fn ->
                     stream
                     |> Paco.Stream.parse!(parser)
                     |> Enum.to_list
                   end
    end
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
      Failed to match lit("") at 1:1, because it didn't consume any input
      """
    }]
  end

  test "parse always ends with a failure" do
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
      Failed to match lit("aa") at 1:3
      """
    }]
  end

  test "parse stream when downstream halts the pipe as first command" do
    stream = ["a", "b", "c"]
             |> Stream.each(&Helper.count(:upstream_called, &1))
             |> Paco.Stream.parse(lit("a"))

    downstream_accumulator = make_ref
    result = Enumerable.reduce(stream,
                               {:halt, downstream_accumulator},
                               fn(_, _) ->
                                 Helper.count(:downstream_called)
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
    stream = ["a", "b", "c"]
             |> Stream.each(&Helper.count(:upstream_called, &1))
             |> Paco.Stream.parse(lit("a"))

    downstream_accumulator = make_ref
    result = Enumerable.reduce(stream,
                               {:suspend, downstream_accumulator},
                               fn(_, _) ->
                                 Helper.count(:downstream_called)
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
    result = ["a", "b", "c", "a", "b", "c"]
             |> Stream.each(&Helper.count(:upstream_called, &1))
             |> Paco.Stream.parse(lit("abc"))
             |> Stream.each(&Helper.count(:downstream_called, &1))
             |> Stream.take(1)
             |> Enum.to_list

    assert result == ["abc"]
    assert Process.get(:upstream_called, 0) == 6     # should have been 3???
    assert Process.get(:downstream_called, 0) == 2   # should have been 1???
  end

  test "parse stream when upstream halts" do
    result = ["a", "b", "c", "a", "b", "c"]
             |> Stream.each(&Helper.count(:upstream_called, &1))
             |> Stream.take(4)
             |> Paco.Stream.parse(lit("abc"))
             |> Stream.each(&Helper.count(:downstream_called, &1))
             |> Enum.to_list

    # When the stream is halted from upstream and the parser is waiting
    # for more data we don't return a failure but we truncate the stream.
    # This behaviour is compatibile with Stream.chunk
    assert result == ["abc"]
    assert Helper.counted(:upstream_called) == 5    # should have been 4???
    assert Helper.counted(:downstream_called) == 1
  end
end
