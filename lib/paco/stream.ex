defmodule Paco.Stream do

  def parse!(upstream, %Paco.Parser{} = parser) do
    parse(upstream, parser, on_failure: :raise)
  end

  def parse(upstream, %Paco.Parser{} = parser, opts \\ []) do
    on_failure = Keyword.get(opts, :on_failure, :halt)
    &do_parse(upstream, {start_link(parser), parser, on_failure}, &1, &2)
  end

  defp do_parse(upstream, configuration, {:suspend, downstream_accumulator}, downstream_reducer) do
    {:suspended, downstream_accumulator, &do_parse(upstream, configuration, &1, downstream_reducer)}
  end
  defp do_parse(_, {running_parser, _, _}, {:halt, downstream_accumulator}, _) do
    stop(running_parser)
    {:halted, downstream_accumulator}
  end
  defp do_parse(upstream, {running_parser, _, _} = configuration, downstream_command, downstream_reducer) do
    stream = Stream.transform(upstream, configuration, &transform/2)
    run(stream, running_parser, downstream_command, downstream_reducer)
  end

  defp start_link(parser) do
    # IO.puts("START PARSER PROCESS")
    running_parser = spawn_link(Paco, :parse, [parser, "", [stream: self]])
    consume_request_for_more_input_from(running_parser)
    running_parser
  end

  defp transform(upstream_element, {running_parser, parser, on_failure}) do
    # IO.puts("LOAD #{upstream_element} TO #{inspect(running_parser)}")
    send(running_parser, {:load, upstream_element})
    receive do
      {^running_parser, :more} ->
        # IO.puts("PARSER NEEDS MORE INPUT")
        {[], {running_parser, parser, on_failure}}
      {^running_parser, {:ok, parsed}} ->
        # IO.puts("PARSED! #{inspect(parsed)}")
        {[parsed], {start_link(parser), parser, on_failure}}
      {^running_parser, {:error, failure}} ->
        case on_failure do
          :halt -> {:halt, failure}
          :yield -> {[{:error, failure}], {start_link(parser), parser, on_failure}}
          :raise -> raise failure
        end
    end
  end

  defp run(stream, running_parser, downstream_command, downstream_reducer) do
    try do
      Enumerable.reduce(stream, downstream_command, downstream_reducer)
    catch
      kind, reason ->
        stacktrace = System.stacktrace
        stop(running_parser)
        :erlang.raise(kind, reason, stacktrace)
    else
      {:suspended, acc, downstream_continuation} ->
        {:suspended, acc, &run(stream, running_parser, &1, downstream_continuation)}
      {_, _} = halted_or_done ->
        # IO.puts("UPSTRAM IS #{inspect(halted_or_done)}")
        stop(running_parser)
        halted_or_done
    end
  end

  defp stop(running_parser) do
    # IO.puts("STOP PARSER PROCESS")
    if Process.alive?(running_parser) do
      send(running_parser, :halt)
      receive do
        {^running_parser, {:error, failure}} -> failure
      end
    end
  end

  defp consume_request_for_more_input_from(running_parser) do
    receive do
      {^running_parser, :more} -> :ok
    end
  end
end
