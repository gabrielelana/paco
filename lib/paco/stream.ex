defmodule Paco.Stream do

  def from(upstream, %Paco.Parser{} = parser) do
    &parse(upstream, start_link(parser), parser, &1, &2)
  end

  defp parse(upstream, running_parser, parser, {:suspend, downstream_accumulator}, downstream_reducer) do
    {:suspended, downstream_accumulator, &parse(upstream, running_parser, parser, &1, downstream_reducer)}
  end
  defp parse(_upstream, running_parser, _parser, {:halt, downstream_accumulator}, _downstream_reducer) do
    stop(running_parser)
    {:halted, downstream_accumulator}
  end
  defp parse(upstream, running_parser, parser, downstream_command, downstream_reducer) do
    stream = Stream.transform(upstream, {running_parser, parser}, &transform/2)
    run(stream, running_parser, downstream_command, downstream_reducer)
  end

  defp start_link(parser) do
    # IO.puts("START PARSER PROCESS")
    running_parser = spawn_link(Paco, :parse, [parser, "", [stream: self]])
    # TODO: extract consume_request_for_more_input
    receive do
      {^running_parser, :more} ->
        # IO.puts("PARSER NEEDS MORE INPUT")
        :ok
    end
    running_parser
  end

  defp transform(upstream_element, {running_parser, parser}) do
    # IO.puts("LOAD #{upstream_element} TO #{inspect(parser)}")
    send(running_parser, {:load, upstream_element})
    receive do
      {^running_parser, :more} ->
        # IO.puts("PARSER NEEDS MORE INPUT")
        {[], {running_parser, parser}}
      {^running_parser, {:ok, parsed}} ->
        # IO.puts("PARSED! #{inspect(parsed)}")
        {[parsed], {start_link(parser), parser}}
      {^running_parser, {:error, failure}} ->
        # IO.puts("FAILURE! #{inspect(failure)}")
        # TODO: if Paco.stream, restart the parser, you will need the parser beside the parser process
        {[failure], {running_parser, parser}}
        # TODO: if Paco.stream!, {:halt, nil}
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
end
